#!/bin/env bash

# Copyright 2017 D2L Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eux
set -o pipefail

die() {
  >&2 echo "${1}"
  exit "${2:-1}"
}

checkVersions() {
  jq --version
}

getStackOutputs() {
  OUTPUT="$(aws cloudformation describe-stacks --stack-name "${1}" | jq '.Stacks[0].Outputs | .[]')"
}

getDevTemplateURL() {
  OUTPUT="$(aws cloudformation package --template-file "totem-client/src/cfn/main/totem-package.yaml" --s3-bucket "${TOTEM_BUCKET_NAME}" --s3-prefix "${s3Prefix}" --kms-key-id "${TOTEM_KMS_KEY_ID}" | sed -n -e '/TemplateURL/s/^[[:blank:]]*TemplateURL:[[:blank:]]*//p' -e 's/[[:blank:]]*$//')"
}

getStackOutput() {
  OUTPUT="$(echo "${1}" | jq -r 'select(.OutputKey=="'"${2}"'").OutputValue')"

  if [ -z "${OUTPUT}" ] 
  then
    die "ERROR: Cannot find output in stack. [stack name = '${3}', output name = '${2}']"
  fi
}

TOTEM_BUCKET_NAME="${TOTEM_BUCKET_NAME:-$(echo $CODEBUILD_SOURCE_VERSION | grep -oP 'arn:aws:s3:::\K[^/]+')}"
TOTEM_KMS_KEY_ID="${TOTEM_KMS_KEY_ID:-${CODEBUILD_KMS_KEY_ID}}"
s3Prefix=blue-green-artifacts
totemCfnPath="totem-client/src/cfn/main"
totemTemplateInput="${totemCfnPath}/totem-blue-green.yaml.template"
totemTemplateOutput="${totemCfnPath}/totem-blue-green.yaml.packaged"
totemPackageOutput="totem-blue-green.yaml"

echo "Build started on `date`"

checkVersions

getDevTemplateURL; devTemplateURL="${OUTPUT}"

if getStackOutputs "${TOTEM_BLUE_GREEN_STACK_NAME}"
then
  echo "Stack found; fetching outputs."
  stackOutputs="${OUTPUT}"

  getStackOutput "${stackOutputs}" FinalColor "${TOTEM_BLUE_GREEN_STACK_NAME}"
  color="${OUTPUT}"

  getStackOutput "${stackOutputs}" FinalIsFirstRun "${TOTEM_BLUE_GREEN_STACK_NAME}"
  isFirstRun="${OUTPUT}"

  getStackOutput "${stackOutputs}" FinalProdTemplateURL "${TOTEM_BLUE_GREEN_STACK_NAME}"
  prodTemplateURL="${OUTPUT}"
else
  echo "Stack not found; using default values."

  color=GREEN
  isFirstRun=true
  prodTemplateURL="${devTemplateURL}"
fi

sed -e 's#@DEV_TEMPLATE_URL@#'"${devTemplateURL}"'#g' \
    -e 's#@PROD_TEMPLATE_URL@'"#${prodTemplateURL}"'#g' \
    -e 's#@COLOR@#'"${color}"'#g' \
    -e 's#@IS_FIRST_RUN@#'"${isFirstRun}"'#g' \
    "${totemTemplateInput}" > "${totemTemplateOutput}"

aws cloudformation package --template-file "${totemTemplateOutput}" --s3-bucket "${TOTEM_BUCKET_NAME}" --s3-prefix "${s3Prefix}" --kms-key-id "$TOTEM_KMS_KEY_ID" --output-template-file "${totemPackageOutput}"
aws cloudformation validate-template --template-body "file://${totemPackageOutput}"
