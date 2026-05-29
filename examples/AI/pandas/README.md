# Running of panda frame on CPU and Nvidia GPU.
There is no way to calculate panda frame on MPS.

Running of sql query on GPU takes 
```
0.47809386253356934
```
whereas same query takes 11s on CPU

Requirement: Parquet file is downloaded from external soruce
and will take some time in first run to download a file.

## profiler on python code
```
%%cudf.pandas.line_profile
```
                                             Total time elapsed: 6.601 seconds

                                                           Stats

┏━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━┳━━━━━━━━━━━━━┓
┃ Line no. ┃ Line                                                                     ┃ GPU TIME(s) ┃ CPU TIME(s) ┃
┡━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━╇━━━━━━━━━━━━━┩
│ 2        │     import os                                                            │             │             │
│          │                                                                          │             │             │
│ 3        │     import urllib.request                                                │             │             │
│          │                                                                          │             │             │
│ 4        │     import pandas as pd                                                  │             │             │
│          │                                                                          │             │             │
│ 5        │     import numpy as np                                                   │             │             │
│          │                                                                          │             │             │
│ 6        │     import time                                                          │             │             │
│          │                                                                          │             │             │
│ 8        │     PARQUET_URL = "https://data.rapids.ai/datasets/nyc_parking/nyc_park… │             │             │
│          │                                                                          │             │             │
│ 9        │     PARQUET_PATH = "/tmp/nyc_parking_violations_2022.parquet"            │             │             │
│          │                                                                          │             │             │
│ 11       │     pd.set_option("display.max_rows", None)                              │             │             │
│          │                                                                          │             │             │
│ 13       │     def download_if_missing(url: str, path: str) -> None:                │             │             │
│          │                                                                          │             │             │
│ 14       │         if not os.path.exists(path):                                     │             │             │
│          │                                                                          │             │             │
│ 19       │             print(f"Using cached file: {path}")                          │             │             │
│          │                                                                          │             │             │
│ 23       │     def test_case1():                                                    │             │             │
│          │                                                                          │             │             │
│ 24       │         download_if_missing(PARQUET_URL, PARQUET_PATH)                   │             │             │
│          │                                                                          │             │             │
│ 25       │         df = pd.read_parquet(PARQUET_PATH, columns=["Registration State… │ 0.225978210 │             │
│          │                                                                          │             │             │
│ 26       │         print(f"Shape: {df.shape}")                                      │ 0.000227923 │             │
│          │                                                                          │             │             │
│ 27       │         print(df[["Registration State", "Violation Description"]]  # ge… │ 0.022870687 │             │
│          │                                                                          │             │             │
│ 28       │          .value_counts()                                                 │ 0.061230645 │             │
│          │                                                                          │             │             │
│ 29       │          .groupby("Registration State")                                  │ 0.002496507 │             │
│          │                                                                          │             │             │
│ 30       │          .head(1)                                                        │ 0.028088262 │             │
│          │                                                                          │             │             │
│ 31       │          .sort_index()                                                   │ 0.004641413 │             │
│          │                                                                          │             │             │
│ 32       │          .reset_index()                                                  │ 0.000681624 │             │
│          │                                                                          │             │             │
│ 35       │     def test_case2():                                                    │             │             │
│          │                                                                          │             │             │
│ 36       │         download_if_missing(PARQUET_URL, PARQUET_PATH)                   │             │             │
│          │                                                                          │             │             │
│ 37       │         df = pd.read_parquet(PARQUET_PATH, columns=["Vehicle Body Type"… │ 0.141076985 │             │
│          │                                                                          │             │             │
│ 38       │         print(df                                                         │ 0.092912211 │             │
│          │                                                                          │             │             │
│ 39       │          .groupby(["Vehicle Body Type"])                                 │ 0.007875229 │             │
│          │                                                                          │             │             │
│ 40       │          .agg({"Summons Number": "count"})                               │ 0.023885510 │             │
│          │                                                                          │             │             │
│ 41       │          .rename(columns={"Summons Number": "Count"})                    │ 0.001522345 │             │
│          │                                                                          │             │             │
│ 42       │          .sort_values(["Count"], ascending=False)                        │ 0.004327511 │             │
│          │                                                                          │             │             │
│ 46       │     start = time.time()                                                  │             │             │
│          │                                                                          │             │             │
│ 47       │     test_case1()                                                         │             │             │
│          │                                                                          │             │             │
│ 48       │     test_case2()                                                         │             │             │
│          │                                                                          │             │             │
│ 49       │     time.time() - start                                                  │             │             │
│          │                                                                          │             │             │
└──────────┴──────────────────────────────────────────────────────────────────────────┴─────────────┴─────────────┘
