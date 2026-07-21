#!/bin/bash

# Define color variables
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'

# Define text formatting variables
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

# Welcome message
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}   ENABLING SENSITIVE DATA PROTECTION DISCOVERY FOR CLOUD STORAGE ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}                     RYAN ARYA PRAMUDYA                          ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo ""

# Step 1: Get TEMPLATE_ID
echo "${BLUE_TEXT}${BOLD_TEXT}[Step 1] Fetching TEMPLATE_ID from Google Cloud DLP API...${RESET_FORMAT}"
export TEMPLATE_ID=$(curl -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
"https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/inspectTemplates" | jq -r '.inspectTemplates[0].name')

echo "${GREEN_TEXT}✓ Template ID: $TEMPLATE_ID${RESET_FORMAT}"
echo ""

# Step 2: Create an inspection template JSON file
echo "${MAGENTA_TEXT}${BOLD_TEXT}[Step 2] Creating inspection_template.json...${RESET_FORMAT}"
cat <<EOF > inspection_template.json
{
  "inspectTemplate": {
    "displayName": "Inspection Template for US SSN",
    "description": "This template was created as part of a Sensitive Data Protection profiler configuration and was modified for deeper inspection for US Social Security numbers.",
    "inspectConfig": {
      "infoTypes": [
        {
          "name": "US_SOCIAL_SECURITY_NUMBER"
        }
      ],
      "minLikelihood": "UNLIKELY"
    }
  }
}
EOF
echo "${GREEN_TEXT}✓ inspection_template.json created!${RESET_FORMAT}"
echo ""

# Step 3: Updating the inspection template
echo "${CYAN_TEXT}${BOLD_TEXT}[Step 3] Updating the inspection template using Google Cloud API...${RESET_FORMAT}"
curl -X PATCH -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
-d @inspection_template.json \
"https://dlp.googleapis.com/v2/$TEMPLATE_ID"
echo ""
echo "${GREEN_TEXT}✓ Inspection template updated!${RESET_FORMAT}"
echo ""

# Step 4: Create a de-identification template JSON file
echo "${YELLOW_TEXT}${BOLD_TEXT}[Step 4] Creating deidentify-template.json...${RESET_FORMAT}"
cat <<EOF > deidentify-template.json
{
  "deidentifyTemplate": {
    "displayName": "Deidentify Template for SSN and Message",
    "description": "Deidentifies SSN, Email and InfoTypes",
    "deidentifyConfig": {
      "recordTransformations": {
        "fieldTransformations": [
          {
            "fields": [
              {
                "name": "ssn"
              },
              {
                "name": "email"
              }
            ],
            "primitiveTransformation": {
              "replaceConfig": {
                "newValue": {
                  "stringValue": "[redacted]"
                }
              }
            }
          },
          {
            "fields": [
              {
                "name": "message"
              }
            ],
            "infoTypeTransformations": {
              "transformations": [
                {
                  "infoTypes": [
                    {
                      "name": "US_SOCIAL_SECURITY_NUMBER"
                    }
                  ],
                  "primitiveTransformation": {
                    "replaceWithInfoTypeConfig": {}
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}
EOF
echo "${GREEN_TEXT}✓ deidentify-template.json created!${RESET_FORMAT}"
echo ""

# Step 5: Post deidentify template
echo "${BLUE_TEXT}${BOLD_TEXT}[Step 5] Posting deidentify template to DLP API...${RESET_FORMAT}"
curl -X POST -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
-d @deidentify-template.json \
"https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/deidentifyTemplates"

echo ""
echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT} LAB COMPLETED SUCCESSFULLY - RYAN ARYA PRAMUDYA                 ${RESET_FORMAT}"
echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
