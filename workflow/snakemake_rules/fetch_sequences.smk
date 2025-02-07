"""
This part of the workflow handles fetching sequences and metadata from GISAID
or NCBI GenBank/Biosample. Depends on the main Snakefile to define the variable
`database`, which is NOT a wildcard.

If the config contains `s3_dst`,`s3_src`, and `fetch_from_database=False`,
then files will be fetched from the AWS S3 bucket. Or else, the data is fetched
directly from the databases.

Produces different final outputs for GISAID vs GenBank:
    GISAID:
        ndjson = "data/gisaid.ndjson"
    GenBank:
        ndjson = "data/genbank.ndjson"
        biosample = "data/biosample.ndjson"
        cog_uk_accessions = "data/cog_uk_accessions.tsv"
        cog_uk_metadata = "data/cog_uk_metadata.csv.gz"
"""

def run_shell_command_n_times(cmd, msg, cleanup_failed_cmd, retry_num=5):
    attempt = 0
    while attempt < retry_num:
        print(f"{msg} attempt number {attempt}")
        try:
            shell(cmd)
            break
        except CalledProcessError:
            print("...FAILED")
            attempt+=1
            shell("{cleanup_failed_cmd} && sleep 10")
    else:
        print(msg + f" has FAILED {retry_num} times. Exiting.")
        raise Exception("function run_shell_command_n_times has failed")

rule fetch_main_ndjson:
    message:
        """Fetching data using the database API"""
    output:
        ndjson = temp(f"data/{database}.ndjson")
    run:
        if database == "gisaid":
            cmd = f"./bin/fetch-from-gisaid {output.ndjson}"
        else:
            cmd = f"./bin/fetch-from-genbank > {output.ndjson}"

        run_shell_command_n_times(
            cmd,
            f"Fetching from {database}",
            f"rm {output.ndjson}"
        )

rule fetch_biosample:
    message:
        """Fetching BioSample data (GenBank only)"""
    output:
        biosample = temp("data/biosample.ndjson")
    run:
        run_shell_command_n_times(
            f"./bin/fetch-from-biosample > {output.biosample}",
            "Fetch BioSample",
            f"rm {output.biosample}"
        )

rule fetch_cog_uk_accessions:
    message:
        """Fetching COG-UK sample accesions (GenBank only)"""
    output:
        cog_uk_accessions = temp("data/cog_uk_accessions.tsv")
    run:
        run_shell_command_n_times(
            f"./bin/fetch-from-cog-uk-accessions > {output.cog_uk_accessions}",
            "Fetch COG-UK sample accessions",
            f"rm {output.cog_uk_accessions}"
        )

rule fetch_cog_uk_metadata:
    message:
        """Fetching COG-UK metadata (GenBank only)"""
    output:
        cog_uk_metadata = temp("data/cog_uk_metadata.csv.gz")
    run:
        run_shell_command_n_times(
            f"./bin/fetch-from-cog-uk-metadata > {output.cog_uk_metadata}",
            "Fetch COG-UK metadata",
            f"rm {output.cog_uk_metadata}"
        )

# Only include rules to fetch from S3 if S3 config params are provided
if config.get("s3_dst") and config.get("s3_src"):

    # Set ruleorder since these fetch rules have the same output
    # Fetch directly from databases when `fetch_from_database=True`
    # or else fetch files from AWS S3 buckets
    if config.get("fetch_from_database", False):
        ruleorder: fetch_main_ndjson > fetch_main_ndjson_from_s3
        ruleorder: fetch_biosample > fetch_biosample_from_s3
    else:
        ruleorder: fetch_main_ndjson_from_s3 > fetch_main_ndjson
        ruleorder:  fetch_biosample_from_s3 > fetch_biosample

    rule fetch_main_ndjson_from_s3:
        message:
            """Fetching main NDJSON from AWS S3"""
        params:
            file_on_s3_dst= f"{config['s3_dst']}/{database}.ndjson.xz",
            file_on_s3_src= f"{config['s3_src']}/{database}.ndjson.xz"
        output:
            ndjson = temp(f"data/{database}.ndjson")
        shell:
            """
            ./bin/download-from-s3 {params.file_on_s3_dst} {output.ndjson} ||  \
            ./bin/download-from-s3 {params.file_on_s3_src} {output.ndjson}
            """

    rule fetch_biosample_from_s3:
        message:
            """Fetching BioSample NDJSON from AWS S3"""
        params:
            file_on_s3_dst= f"{config['s3_dst']}/biosample.ndjson.gz",
            file_on_s3_src= f"{config['s3_src']}/biosample.ndjson.gz"
        output:
            biosample = temp("data/biosample.ndjson")
        shell:
            """
            ./bin/download-from-s3 {params.file_on_s3_dst} {output.biosample} ||  \
            ./bin/download-from-s3 {params.file_on_s3_src} {output.biosample}
            """
