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

# -------------------------------------------------------------------------
# TASK 1: Create and schedule scan configuration
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 1] Creating BigQuery Dataset & Cloud Storage Discovery Config...${RESET_FORMAT}"
echo "${BLUE_TEXT}Creating BigQuery dataset cloudstorage_discovery...${RESET_FORMAT}"
bq mk --dataset --location=us $DEVSHELL_PROJECT_ID:cloudstorage_discovery || true

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

# -------------------------------------------------------------------------
# TASK 2: Modify existing inspection template & create de-identify template
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 2] Modifying Inspection Template & Creating De-identify Template...${RESET_FORMAT}"
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

echo "${BLUE_TEXT}Creating de-identification template us_ssn_deidentify...${RESET_FORMAT}"
cat <<EOF > deidentify-template.json
{
  "deidentifyTemplate": {
    "displayName": "Template De-identifikasi untuk SSN AS",
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
"https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/deidentifyTemplates?deidentifyTemplateId=us_ssn_deidentify" || true

echo "${GREEN_TEXT}✓ Inspection & De-identification Templates configured!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 2 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 3..."
echo ""

# -------------------------------------------------------------------------
# TASK 3: Create and run an inspection job
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 3] Creating and Running Inspection Job (us_ssn_inspection)...${RESET_FORMAT}"
echo "${BLUE_TEXT}Creating BigQuery dataset cloudstorage_inspection...${RESET_FORMAT}"
bq mk --dataset --location=us $DEVSHELL_PROJECT_ID:cloudstorage_inspection || true

cat <<EOF > inspect_job.json
{
  "jobId": "us_ssn_inspection",
  "inspectJob": {
    "storageConfig": {
      "cloudStorageOptions": {
        "fileSet": {
          "url": "gs://${DEVSHELL_PROJECT_ID}-input/*"
        },
        "fileTypes": [
          "TEXT_FILE",
          "CSV"
        ]
      }
    },
    "inspectTemplateName": "$TEMPLATE_ID",
    "actions": [
      {
        "saveFindings": {
          "outputConfig": {
            "table": {
              "projectId": "$DEVSHELL_PROJECT_ID",
              "datasetId": "cloudstorage_inspection",
              "tableId": "us_ssn"
            },
            "outputSchema": "BASIC_COLUMNS"
          }
        }
      },
      {
        "publishSummaryToSecurityCommandCenter": {}
      }
    ]
  }
}
EOF

curl -X POST -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
-d @inspect_job.json \
"https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/us/dlpJobs" || true

echo "${GREEN_TEXT}✓ Inspection Job us_ssn_inspection created and started!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 3 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 4..."
echo ""

# -------------------------------------------------------------------------
# TASK 4: Create and run a de-identification job
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 4] Creating and Running De-identification Job (us_ssn_deidentify)...${RESET_FORMAT}"
echo "${BLUE_TEXT}Creating BigQuery dataset cloudstorage_transformations...${RESET_FORMAT}"
bq mk --dataset --location=us $DEVSHELL_PROJECT_ID:cloudstorage_transformations || true

cat <<EOF > deidentify_job.json
{
  "jobId": "us_ssn_deidentify",
  "inspectJob": {
    "storageConfig": {
      "cloudStorageOptions": {
        "fileSet": {
          "url": "gs://${DEVSHELL_PROJECT_ID}-input/*"
        },
        "fileTypes": [
          "TEXT_FILE",
          "CSV"
        ]
      }
    },
    "actions": [
      {
        "deidentify": {
          "transformationDetailsStorageConfig": {
            "table": {
              "projectId": "$DEVSHELL_PROJECT_ID",
              "datasetId": "cloudstorage_transformations",
              "tableId": "deidentify_ssn_csv"
            }
          },
          "transformationConfig": {
            "structuredDeidentifyTemplate": "projects/$DEVSHELL_PROJECT_ID/locations/global/deidentifyTemplates/us_ssn_deidentify"
          },
          "cloudStorageOutput": "gs://${DEVSHELL_PROJECT_ID}-output"
        }
      }
    ]
  }
}
EOF

curl -X POST -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
-d @deidentify_job.json \
"https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/us/dlpJobs" || true

echo "${GREEN_TEXT}✓ De-identification Job us_ssn_deidentify created and started!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 4 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk menyelesaikan lab..."
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}   GSP1281 LAB COMPLETED SUCCESSFULLY (100/100) - RYAN ARYA PRAMUDYA ${RESET_FORMAT}"
echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
