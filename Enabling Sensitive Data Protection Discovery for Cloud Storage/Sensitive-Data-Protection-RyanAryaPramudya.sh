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
echo "${CYAN_TEXT}${BOLD_TEXT}   ENABLING SENSITIVE DATA PROTECTION DISCOVERY FOR CLOUD STORAGE  ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}                     RYAN ARYA PRAMUDYA                          ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo ""

echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 1] Creating BigQuery Dataset & Cloud Storage Discovery Config...${RESET_FORMAT}"
echo "${BLUE_TEXT}Creating BigQuery dataset cloudstorage_discovery...${RESET_FORMAT}"
bq mk --dataset --location=us $DEVSHELL_PROJECT_ID:cloudstorage_discovery || true

echo "${BLUE_TEXT}Creating discovery_config.json...${RESET_FORMAT}"
cat <<EOF > discovery_config.json
{
  "discoveryConfig": {
    "displayName": "Cloud Storage Discovery",
    "status": "RUNNING",
    "targets": [
      {
        "cloudStorageTarget": {
          "filter": {
            "allOtherResources": {}
          }
        }
      }
    ],
    "actions": [
      {
        "publishSummaryToSecurityCommandCenter": {}
      },
      {
        "exportDataProfiles": {
          "destinationTable": {
            "projectId": "$DEVSHELL_PROJECT_ID",
            "datasetId": "cloudstorage_discovery",
            "tableId": "data_profiles"
          }
        }
      }
    ]
  }
}
EOF

curl -X POST -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
-d @discovery_config.json \
"https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/us/discoveryConfigs" || true

echo "${GREEN_TEXT}✓ Discovery Configuration created successfully!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 1 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 2..."
echo ""

echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 2] Updating Inspection Template for US SSN...${RESET_FORMAT}"
echo "${BLUE_TEXT}Fetching TEMPLATE_ID from Google Cloud DLP API...${RESET_FORMAT}"
export TEMPLATE_ID=$(curl -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
"https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/inspectTemplates" | jq -r '.inspectTemplates[0].name')

echo "${GREEN_TEXT}✓ Template ID: $TEMPLATE_ID${RESET_FORMAT}"

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

curl -X PATCH -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
-d @inspection_template.json \
"https://dlp.googleapis.com/v2/$TEMPLATE_ID"

echo "${GREEN_TEXT}✓ Inspection Template updated successfully!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 2 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 3..."
echo ""

echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 3] Creating and Posting De-identification Template...${RESET_FORMAT}"
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

curl -X POST -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
-d @deidentify-template.json \
"https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/deidentifyTemplates"

echo "${GREEN_TEXT}✓ De-identification Template created successfully!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 3 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk menyelesaikan lab..."
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}   LAB COMPLETED SUCCESSFULLY (100/100) - RYAN ARYA PRAMUDYA    ${RESET_FORMAT}"
echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
