#!/bin/bash

REGION=us-east-1
IDENTITY_STORE_ID=$(aws sso-admin list-instances --region $REGION --query "Instances[0].IdentityStoreId" --output text)
GROUP_IDS=$(aws identitystore list-groups --region $REGION --identity-store-id $IDENTITY_STORE_ID --query 'Groups[?DisplayName == `AWSAdmins` || DisplayName == `AWSPowerUsers`].GroupId' --output text)

for GROUP_ID in $GROUP_IDS; do
  # Get all membership IDs in the group
  MEMBERSHIP_IDS=$(aws identitystore list-group-memberships --region $REGION --identity-store-id $IDENTITY_STORE_ID --group-id $GROUP_ID --query 'GroupMemberships[*].MembershipId' --output text)

  # Loop through each membership ID and get detailed user information
  for MEMBERSHIP_ID in $MEMBERSHIP_IDS; do
    USER_ID=$(aws identitystore describe-group-membership --region $REGION --identity-store-id $IDENTITY_STORE_ID --membership-id $MEMBERSHIP_ID --query 'MemberId.UserId' --output text)
    aws identitystore describe-user --region $REGION --identity-store-id $IDENTITY_STORE_ID --user-id $USER_ID
  done
done
