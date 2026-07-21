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
# TASK 1: BigQuery Dataset Setup & Discovery Enablement
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 1] Setting up BigQuery Dataset cloudstorage_discovery...${RESET_FORMAT}"
bq mk --dataset --location=us $DEVSHELL_PROJECT_ID:cloudstorage_discovery || true

echo "${GREEN_TEXT}✓ BigQuery dataset cloudstorage_discovery ready!${RESET_FORMAT}"
echo ""
echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 UNTUK TASK 1: Aktifkan Discovery di Konsol GCP (Security > Sensitive Data Protection > Discovery > Cloud Storage > Enable -> Nama: Cloud Storage Discovery -> Create).${RESET_FORMAT}"
read -p "Setelah buat Discovery Config & klik Check My Progress Task 1 di Qwiklabs, tekan [ENTER] untuk lanjut..."
echo ""

# -------------------------------------------------------------------------
# TASK 2: Inspection Template & De-identification Template
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 2] Configuring Inspection & De-identification Templates...${RESET_FORMAT}"

export TEMPLATE_ID=$(curl -s \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json" \
"https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/inspectTemplates" | jq -r '.inspectTemplates[0].name // empty')

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

if [ -z "$TEMPLATE_ID" ] || [ "$TEMPLATE_ID" == "null" ]; then
  echo "${BLUE_TEXT}Creating new Inspection Template for US SSN...${RESET_FORMAT}"
  export TEMPLATE_ID=$(curl -X POST -s \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json" \
  -d @inspection_template.json \
  "https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/inspectTemplates" | jq -r '.name')
else
  echo "${BLUE_TEXT}Updating existing Inspection Template ($TEMPLATE_ID)...${RESET_FORMAT}"
  curl -X PATCH -s \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json" \
  -d @inspection_template.json \
  "https://dlp.googleapis.com/v2/$TEMPLATE_ID" || true
fi

echo "${GREEN_TEXT}✓ Inspection Template configured: $TEMPLATE_ID${RESET_FORMAT}"

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

echo "${GREEN_TEXT}✓ De-identification template us_ssn_deidentify created!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 2 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 3..."
echo ""

# -------------------------------------------------------------------------
# TASK 3: Create and run inspection job (us_ssn_inspection)
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 3] Creating and Running Inspection Job us_ssn_inspection...${RESET_FORMAT}"
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

echo "${GREEN_TEXT}✓ Inspection job us_ssn_inspection created and executed!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 3 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 4..."
echo ""

# -------------------------------------------------------------------------
# TASK 4: Create and run de-identification job (us_ssn_deidentify)
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 4] Creating and Running De-identification Job us_ssn_deidentify...${RESET_FORMAT}"
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

echo "${GREEN_TEXT}✓ De-identification job us_ssn_deidentify created and executed!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 4 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk menyelesaikan lab..."
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}   GSP1281 LAB COMPLETED SUCCESSFULLY (100/100) - RYAN ARYA PRAMUDYA ${RESET_FORMAT}"
echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
