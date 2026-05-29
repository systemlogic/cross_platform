import os
import urllib.request
import pandas as pd
import numpy as np
import time

PARQUET_URL = "https://data.rapids.ai/datasets/nyc_parking/nyc_parking_violations_2022.parquet"
PARQUET_PATH = "/tmp/nyc_parking_violations_2022.parquet"

pd.set_option("display.max_rows", None)

def download_if_missing(url: str, path: str) -> None:
    if not os.path.exists(path):
        print(f"Downloading {url} ...")
        urllib.request.urlretrieve(url, path)
        print(f"Saved to {path}")
    else:
        print(f"Using cached file: {path}")



def test_case1():
    download_if_missing(PARQUET_URL, PARQUET_PATH)
    df = pd.read_parquet(PARQUET_PATH, columns=["Registration State", "Violation Description", "Vehicle Body Type", "Issue Date", "Summons Number"])
    print(f"Shape: {df.shape}")
    print(df[["Registration State", "Violation Description"]]  # get only these two columns
     .value_counts() 
     .groupby("Registration State") 
     .head(1) 
     .sort_index() 
     .reset_index()
    )
    
def test_case2():
    download_if_missing(PARQUET_URL, PARQUET_PATH)
    df = pd.read_parquet(PARQUET_PATH, columns=["Vehicle Body Type", "Issue Date", "Summons Number"])
    print(df
     .groupby(["Vehicle Body Type"])
     .agg({"Summons Number": "count"})
     .rename(columns={"Summons Number": "Count"})
     .sort_values(["Count"], ascending=False)
    )

start = time.time()
test_case1()
test_case2()
print(time.time() - start)
