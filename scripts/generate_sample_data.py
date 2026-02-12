import csv
import random
import os
import boto3  # <--- The AWS SDK
from datetime import datetime, timedelta

# --- Configuration ---
BUCKET_NAME = "ayush-final-test-9988776655"  # Your specific bucket name
S3_KEY = "data/temperature_data.csv"         # Where in S3 you want it
LOCAL_FILE = "/tmp/temperature_data.csv"     # Temp location on the worker

def generate_temperature_csv(filename, num_records=1000):
    print(f"Generating {num_records} records to {filename}...")
    
    if num_records < 0:
        raise ValueError("Number of records cannot be negative")

    cities = ["New York", "London", "Tokyo", "Paris", "Sydney", "Mumbai", "Delhi"]
    header = ["city", "temperature", "timestamp"]

    # Ensure local directory exists
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    try:
        with open(filename, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(header)

            for _ in range(num_records):
                city = random.choice(cities)
                temp = round(random.uniform(-10, 45), 1)
                # Random time in the last year
                time = datetime.now() - timedelta(days=random.randint(0, 365))
                
                writer.writerow([city, temp, time.isoformat()])
                
        print("Local file generation successful.")
        
    except (IOError, OSError) as e:
        raise IOError(f"Failed to write to file {filename}: {str(e)}")

def upload_to_s3(local_path, bucket, s3_path):
    print(f"Uploading {local_path} to s3://{bucket}/{s3_path}...")
    s3_client = boto3.client('s3')
    try:
        s3_client.upload_file(local_path, bucket, s3_path)
        print("Upload successful! ✅")
    except Exception as e:
        print(f"Upload failed: {str(e)}")
        raise e

if __name__ == "__main__":
    # 1. Generate the file locally on the worker
    generate_temperature_csv(LOCAL_FILE)
    
    # 2. Upload the file to your S3 bucket
    upload_to_s3(LOCAL_FILE, BUCKET_NAME, S3_KEY)