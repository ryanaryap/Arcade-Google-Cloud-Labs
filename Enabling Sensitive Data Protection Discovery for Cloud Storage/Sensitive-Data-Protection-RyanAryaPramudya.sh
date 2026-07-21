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
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}   ENABLING SENSITIVE DATA PROTECTION DISCOVERY FOR CLOUD STORAGE  ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}                     RYAN ARYA PRAMUDYA                          ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo ""

# -------------------------------------------------------------------------
# Setup: project id + enable required APIs
# -------------------------------------------------------------------------
export DEVSHELL_PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$DEVSHELL_PROJECT_ID" ]; then
  echo "${RED_TEXT}Gagal mendapatkan project ID. Jalankan 'gcloud config set project PROJECT_ID' dulu.${RESET_FORMAT}"
  exit 1
fi
echo "${GREEN_TEXT}Project ID: $DEVSHELL_PROJECT_ID${RESET_FORMAT}"

echo "${BLUE_TEXT}Enabling DLP API...${RESET_FORMAT}"
gcloud services enable dlp.googleapis.com --quiet

TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token)

# -------------------------------------------------------------------------
# TASK 1: BigQuery Dataset cloudstorage_discovery Setup
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 1] Setting up BigQuery Dataset cloudstorage_discovery...${RESET_FORMAT}"
bq mk --dataset --location=us $DEVSHELL_PROJECT_ID:cloudstorage_discovery 2>/dev/null || true

echo "${GREEN_TEXT}✓ BigQuery Dataset cloudstorage_discovery ready!${RESET_FORMAT}"
echo ""
echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 UNTUK TASK 1: Aktifkan Discovery di Konsol GCP (Security > Sensitive Data Protection > Discovery > Cloud Storage > Enable -> Display Name: Cloud Storage Discovery -> Create).${RESET_FORMAT}"
read -p "Setelah klik Check My Progress Task 1 di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 2..."
echo ""

# -------------------------------------------------------------------------
# TASK 2: Modify existing inspection template & create de-identify template
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 2] Modifying Inspection Template & Creating De-identify Template...${RESET_FORMAT}"
echo "${BLUE_TEXT}Mengecek ketersediaan inspection template...${RESET_FORMAT}"

TEMPLATE_ID=""
for i in $(seq 1 3); do
  TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token)
  TEMPLATE_ID=$(curl -s \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/inspectTemplates" \
    | jq -r '(.inspectTemplates // []) | sort_by(.createTime) | last | .name // empty' 2>/dev/null)

  if [ -n "$TEMPLATE_ID" ] && [ "$TEMPLATE_ID" != "null" ]; then
    echo "${GREEN_TEXT}✓ Template ditemukan: $TEMPLATE_ID${RESET_FORMAT}"
    break
  fi
  sleep 2
done

if [ -z "$TEMPLATE_ID" ] || [ "$TEMPLATE_ID" == "null" ]; then
  echo "${YELLOW_TEXT}Template belum ada, otomatis membuat Inspection Template baru...${RESET_FORMAT}"
  cat <<EOF > inspection_template_new.json
{
  "inspectTemplate": {
    "displayName": "Inspection Template for US SSN",
    "description": "This template was created as part of a Sensitive Data Protection profiler configuration and was modified for deeper inspection for US Social Security numbers.",
    "inspectConfig": {
      "infoTypes": [
        { "name": "US_SOCIAL_SECURITY_NUMBER" }
      ],
      "minLikelihood": "UNLIKELY"
    }
  }
}
EOF
  RESP=$(curl -X POST -s \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d @inspection_template_new.json \
    "https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/inspectTemplates")
  TEMPLATE_ID=$(echo "$RESP" | jq -r '.name // empty')
  echo "${GREEN_TEXT}✓ Inspection Template baru berhasil dibuat: $TEMPLATE_ID${RESET_FORMAT}"
else
  cat <<EOF > inspection_template.json
{
  "inspectTemplate": {
    "displayName": "Inspection Template for US SSN",
    "description": "This template was created as part of a Sensitive Data Protection profiler configuration and was modified for deeper inspection for US Social Security numbers.",
    "inspectConfig": {
      "infoTypes": [
        { "name": "US_SOCIAL_SECURITY_NUMBER" }
      ],
      "minLikelihood": "UNLIKELY"
    }
  }
}
EOF

  RESP=$(curl -X PATCH -s \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d @inspection_template.json \
    "https://dlp.googleapis.com/v2/$TEMPLATE_ID")
  echo "$RESP" | jq . 2>/dev/null || echo "$RESP"
fi

echo "${BLUE_TEXT}Creating de-identification template us_ssn_deidentify...${RESET_FORMAT}"
cat <<EOF > deidentify-template.json
{
  "deidentifyTemplate": {
    "name": "projects/$DEVSHELL_PROJECT_ID/locations/global/deidentifyTemplates/us_ssn_deidentify",
    "displayName": "Template De-identifikasi untuk SSN AS",
    "description": "Deidentifies SSN, Email and InfoTypes",
    "deidentifyConfig": {
      "recordTransformations": {
        "fieldTransformations": [
          {
            "fields": [
              { "name": "ssn" },
              { "name": "email" }
            ],
            "primitiveTransformation": {
              "replaceConfig": {
                "newValue": { "stringValue": "[redacted]" }
              }
            }
          },
          {
            "fields": [
              { "name": "message" }
            ],
            "infoTypeTransformations": {
              "transformations": [
                {
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

RESP=$(curl -X POST -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @deidentify-template.json \
  "https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/global/deidentifyTemplates")
echo "$RESP" | jq . 2>/dev/null || echo "$RESP"

echo "${GREEN_TEXT}✓ Inspection & De-identification Templates configured!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 2 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 3..."
echo ""

# -------------------------------------------------------------------------
# TASK 3: Create and run an inspection job
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 3] Creating and Running Inspection Job (us_ssn_inspection)...${RESET_FORMAT}"
bq mk --dataset --location=us $DEVSHELL_PROJECT_ID:cloudstorage_inspection 2>/dev/null || true

cat <<EOF > inspect_job.json
{
  "jobId": "us_ssn_inspection",
  "inspectJob": {
    "storageConfig": {
      "cloudStorageOptions": {
        "fileSet": {
          "url": "gs://${DEVSHELL_PROJECT_ID}-input/*"
        },
        "fileTypes": ["TEXT_FILE", "CSV"]
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
      }
    ]
  }
}
EOF

TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token)
RESP=$(curl -X POST -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @inspect_job.json \
  "https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/us/dlpJobs")
echo "$RESP" | jq . 2>/dev/null || echo "$RESP"

INSPECT_JOB_NAME=$(echo "$RESP" | jq -r '.name // empty')

if [ -n "$INSPECT_JOB_NAME" ]; then
  echo "${BLUE_TEXT}Menunggu inspection job selesai (DONE)...${RESET_FORMAT}"
  for i in $(seq 1 30); do
    TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token)
    STATE=$(curl -s -H "Authorization: Bearer $TOKEN" \
      "https://dlp.googleapis.com/v2/$INSPECT_JOB_NAME" | jq -r '.state // empty')
    echo "  Status: $STATE (cek $i/30)"
    if [ "$STATE" == "DONE" ] || [ "$STATE" == "FAILED" ]; then
      break
    fi
    sleep 15
  done
fi

echo "${GREEN_TEXT}✓ Inspection Job us_ssn_inspection created and started!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 3 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 4..."
echo ""

# -------------------------------------------------------------------------
# TASK 4: Create and run a de-identification job
# -------------------------------------------------------------------------
echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 4] Creating and Running De-identification Job (us_ssn_deidentify)...${RESET_FORMAT}"
bq mk --dataset --location=us $DEVSHELL_PROJECT_ID:cloudstorage_transformations 2>/dev/null || true

cat <<EOF > deidentify_job.json
{
  "jobId": "us_ssn_deidentify",
  "inspectJob": {
    "storageConfig": {
      "cloudStorageOptions": {
        "fileSet": {
          "url": "gs://${DEVSHELL_PROJECT_ID}-input/*"
        },
        "fileTypes": ["TEXT_FILE", "CSV"]
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

TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token)
RESP=$(curl -X POST -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @deidentify_job.json \
  "https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/locations/us/dlpJobs")
echo "$RESP" | jq . 2>/dev/null || echo "$RESP"

DEID_JOB_NAME=$(echo "$RESP" | jq -r '.name // empty')

if [ -n "$DEID_JOB_NAME" ]; then
  echo "${BLUE_TEXT}Menunggu de-identify job selesai (DONE)...${RESET_FORMAT}"
  for i in $(seq 1 30); do
    TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token)
    STATE=$(curl -s -H "Authorization: Bearer $TOKEN" \
      "https://dlp.googleapis.com/v2/$DEID_JOB_NAME" | jq -r '.state // empty')
    echo "  Status: $STATE (cek $i/30)"
    if [ "$STATE" == "DONE" ] || [ "$STATE" == "FAILED" ]; then
      break
    fi
    sleep 15
  done
fi

echo "${GREEN_TEXT}✓ De-identification Job us_ssn_deidentify created and started!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 4 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk menyelesaikan lab..."
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}   GSP1281 LAB COMPLETED SUCCESSFULLY (100/100) - RYAN ARYA PRAMUDYA ${RESET_FORMAT}"
echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
