#!/usr/bin/env python3

from pprint import pprint
from typing import List, Dict, Any

import boto3
from botocore.exceptions import ClientError
from ruamel.yaml import RoundTripRepresenter, YAML


class MigratorRoundTripRepresenter(RoundTripRepresenter):
    def represent_mapping(self, tag, mapping, flow_style=None) -> RoundTripRepresenter:
        if 'name' in mapping:
            mapping.yaml_set_anchor(mapping['name'])
        return RoundTripRepresenter.represent_mapping(self, tag, mapping, flow_style=flow_style)


def represent_merger(self, data):
    return self.represent_scalar(u'tag:yaml.org,2002:merge', u'<<')


def represent_none(self, data):
    return self.represent_scalar(u'tag:yaml.org,2002:null', u'null')


def ignore_aliases(self, data) -> bool:
    return False


yml = YAML()
yml.Representer = MigratorRoundTripRepresenter
yml.preserve_quotes = True
yml.allow_duplicate_keys = True
yml.sort_base_mapping_type_on_output = True
yml.representer.add_representer(type(None), represent_none)
yml.representer.add_representer(u'tag:yaml.org,2002:merge', u'<<')
yml.indent(mapping=2, sequence=4, offset=2)


class SSOAdminClient:
    def __init__(self, region_name: str):
        self.client = boto3.client('sso-admin', region_name=region_name)

    def list_instances(self) -> str:
        try:
            response = self.client.list_instances()
            return response['Instances'][0]['IdentityStoreId']
        except (ClientError, IndexError) as e:
            raise RuntimeError(f"Error fetching IdentityStoreId: {e}")


class IdentityStoreClient:
    def __init__(self, region_name: str, identity_store_id: str):
        self.client = boto3.client('identitystore', region_name=region_name)
        self.identity_store_id = identity_store_id

    def list_groups(self) -> dict:
        group_ids = {}
        try:
            paginator = self.client.get_paginator('list_groups')
            for page in paginator.paginate(IdentityStoreId=self.identity_store_id):
                for group in page['Groups']:
                    group_ids.update({group['DisplayName']: group})
        except ClientError as e:
            raise RuntimeError(f"Error fetching GroupIds: {e}")
        return group_ids

    def list_group_memberships(self, group_id: str) -> List[str]:
        membership_ids = []
        try:
            paginator = self.client.get_paginator('list_group_memberships')
            for page in paginator.paginate(IdentityStoreId=self.identity_store_id, GroupId=group_id):
                for membership in page['GroupMemberships']:
                    membership_ids.append(membership['MembershipId'])
        except ClientError as e:
            raise RuntimeError(f"Error fetching MembershipIds for group {group_id}: {e}")
        return membership_ids

    def get_user_id(self, membership_id: str) -> str:
        try:
            response = self.client.describe_group_membership(
                IdentityStoreId=self.identity_store_id, MembershipId=membership_id)
            return response['MemberId']['UserId']
        except ClientError as e:
            raise RuntimeError(f"Error fetching UserId for membership {membership_id}: {e}")

    def describe_user(self, user_id: str) -> Dict[str, Any]:
        try:
            response = self.client.describe_user(IdentityStoreId=self.identity_store_id, UserId=user_id)
            return response
        except ClientError as e:
            raise RuntimeError(f"Error fetching user information for user {user_id}: {e}")


class SSOManager:
    groups_with_users: dict = {}

    def __init__(self, region_name: str, group_list: list[str]):
        self.sso_admin_client = SSOAdminClient(region_name)
        identity_store_id = self.sso_admin_client.list_instances()
        self.identity_store_client = IdentityStoreClient(region_name, identity_store_id)
        self.group_list = group_list

    def users_groups(self) -> None:
        groups = {key: value for key, value in self.identity_store_client.list_groups().items() if
                  key in self.group_list}
        groups_with_users: dict = {}
        for group_name, group in groups.items():
            membership_ids = self.identity_store_client.list_group_memberships(group.get('GroupId'))
            for membership_id in membership_ids:
                user_id = self.identity_store_client.get_user_id(membership_id)
                user_info = self.identity_store_client.describe_user(user_id)
                if not groups_with_users.get(group_name):
                    groups_with_users.update({group_name: {}})
                groups_with_users[group_name].update({user_info['UserName']: user_info})
                del groups_with_users[group_name][user_info['UserName']]['ResponseMetadata']
        for idx, group in enumerate(sorted(self.group_list)):
            if not self.groups_with_users.get(group):
                self.groups_with_users.update({group: {}})
            self.groups_with_users[group].update({key: groups_with_users[group][key]
                                                  for key in sorted(groups_with_users[group])})


def write_to_yaml(yaml_file_name, yaml_data,
                  mapping=2, sequence=4, offset=2,
                  allow_duplicate_keys=False,
                  explicit_start=True,
                  encoding='utf-8'):
    with open(yaml_file_name, 'w', encoding=encoding) as yaml_writer:
        yml.indent(mapping=mapping, sequence=sequence, offset=offset)
        yml.allow_duplicate_keys = allow_duplicate_keys
        yml.explicit_start = explicit_start
        yml.dump(yaml_data, yaml_writer)


def main() -> None:
    sso_manager = SSOManager('us-east-1', ['AWSAdmins', 'AWSPowerUsers'])
    sso_manager.users_groups()
    write_to_yaml('./.cache/stanza-sso-users.yaml', sso_manager.groups_with_users)


if __name__ == "__main__":
    main()
