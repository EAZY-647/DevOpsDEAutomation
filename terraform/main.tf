#########################
# MAIN RESOURCES
#########################

# Check if the bucket exists
data "aws_s3_bucket" "existing" {
  count  = var.use_existing_bucket ? 1 : 0
  bucket = var.existing_bucket_name
}

locals {
  # We are using a hardcoded unique name to ensure no global conflicts
  bucket_name = "ayush-final-test-9988776655"
}

# Create the S3 bucket
resource "aws_s3_bucket" "raw_data" {
  bucket        = local.bucket_name
  force_destroy = true 

  tags = {
    Name        = local.bucket_name
    Environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create the data directory in the bucket
resource "aws_s3_object" "data_directory" {
  bucket = aws_s3_bucket.raw_data.id
  key    = "data/"
}

# Upload the data file
resource "aws_s3_object" "temperature_data" {
  bucket       = aws_s3_bucket.raw_data.id
  key          = "data/temperature_data.csv"
  source       = "./../data/temperature_data.csv"
  content_type = "text/csv"
}

# Create the Glue IAM role
resource "aws_iam_role" "glue_role" {
  name = "AWSGlueServiceRole-${var.project_name}"
  force_detach_policies = true

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Attach required policies for Glue role
resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_s3_access" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

#########################
# GLUE RESOURCES
#########################

# Glue Catalog Database
resource "aws_glue_catalog_database" "main" {
  name = "${var.project_name}_catalog"

  create_table_default_permission {
    permissions = ["SELECT"]
    principal {
      data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Glue Crawler
resource "aws_glue_crawler" "main" {
  name          = "${var.project_name}-crawler"
  database_name = aws_glue_catalog_database.main.name
  role          = aws_iam_role.glue_role.name
  schedule      = "cron(0 1 * * ? *)"

  s3_target {
    path = "s3://${aws_s3_bucket.raw_data.id}/data/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  lineage_configuration {
    crawler_lineage_settings = "DISABLE"
  }

  lake_formation_configuration {
    use_lake_formation_credentials = false
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableLevelConfiguration = 3
    }
  })

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_s3_bucket.raw_data,
    aws_s3_object.data_directory,
    aws_iam_role_policy_attachment.glue_service_role
  ]
}