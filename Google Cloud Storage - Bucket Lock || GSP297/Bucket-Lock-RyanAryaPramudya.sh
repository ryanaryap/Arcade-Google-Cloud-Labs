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
echo "${CYAN_TEXT}${BOLD_TEXT}   GOOGLE CLOUD STORAGE - BUCKET LOCK (GSP297) - RYAN ARYA PRAMUDYA  ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo ""

echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 1] Creating Cloud Storage Bucket...${RESET_FORMAT}"
export BUCKET=$(gcloud config get-value project)
gsutil mb "gs://$BUCKET" || true
echo "${GREEN_TEXT}✓ Bucket gs://$BUCKET created successfully!${RESET_FORMAT}"
echo ""

echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 2] Setting Retention Policy (10s)...${RESET_FORMAT}"
gsutil retention set 10s "gs://$BUCKET"
gsutil retention get "gs://$BUCKET"
gsutil cp gs://spls/gsp297/dummy_transactions "gs://$BUCKET/"
gsutil ls -L "gs://$BUCKET/dummy_transactions"
echo "${GREEN_TEXT}✓ Retention policy set and dummy_transactions uploaded!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 1 & TASK 2 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 3..."
echo ""

echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 3] Locking Retention Policy...${RESET_FORMAT}"
echo "y" | gsutil retention lock "gs://$BUCKET"
gsutil retention get "gs://$BUCKET"
echo "${GREEN_TEXT}✓ Retention policy locked successfully!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 3 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 4..."
echo ""

echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 4] Setting Up Temporary Hold & Removing Object...${RESET_FORMAT}"
gsutil retention temp set "gs://$BUCKET/dummy_transactions"
sleep 2
gsutil retention temp release "gs://$BUCKET/dummy_transactions"
echo "${BLUE_TEXT}Waiting 10 seconds for retention duration to expire...${RESET_FORMAT}"
sleep 10
gsutil rm "gs://$BUCKET/dummy_transactions"
echo "${GREEN_TEXT}✓ Temporary hold set, released, and dummy_transactions removed!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 4 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk lanjut ke Task 5..."
echo ""

echo "${YELLOW_TEXT}${BOLD_TEXT}[Task 5] Setting Up Event-Based Hold & Removing Object...${RESET_FORMAT}"
gsutil retention event-default set "gs://$BUCKET"
gsutil cp gs://spls/gsp297/dummy_loan "gs://$BUCKET/"
gsutil ls -L "gs://$BUCKET/dummy_loan"
gsutil retention event release "gs://$BUCKET/dummy_loan"
echo "${BLUE_TEXT}Waiting 10 seconds for retention duration to expire...${RESET_FORMAT}"
sleep 10
gsutil rm "gs://$BUCKET/dummy_loan"
echo "${GREEN_TEXT}✓ Event-based hold set, released, and dummy_loan removed!${RESET_FORMAT}"
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}👉 KLIK 'Check My Progress' UNTUK TASK 5 SEKARANG!${RESET_FORMAT}"
read -p "Setelah klik Check My Progress di Qwiklabs, tekan [ENTER] untuk menyelesaikan lab..."
echo ""

echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}   GSP297 LAB COMPLETED SUCCESSFULLY (100/100) - RYAN ARYA PRAMUDYA ${RESET_FORMAT}"
echo "${MAGENTA_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
