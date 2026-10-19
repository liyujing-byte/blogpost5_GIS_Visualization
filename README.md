# Mapping Household Income Across New York Counties

## Project Overview

This repository contains the R code, data, and figures for Blog Post 5: GIS Data Visualization. The analysis asks where higher- and lower-income counties are concentrated in New York and whether nearby counties have similar household incomes.

It covers all 62 New York counties using ACS 2020–2024 five-year estimates. Two maps show statewide patterns and selected NYC-area differences. A supplementary chart shows selected estimates and 90% confidence intervals. The blog article is maintained separately in the website repository.

## Repository Structure

```text
code/
  blogpost5_all_process.R
data/
  acs2024_b19013.dat
  county_boundaries_2024.zip
  county_boundaries_2024/
  ny_county_income.csv
  ny_county_income_map.rds
  county_income_summary.csv
  state_income.csv
  income_comparison.csv
  comparison_counties.csv
figures/
  income_map.png
  nyc_detail.png
  county_comparison.png
README.md
blogpost5_GIS_Visualization.Rproj
```

## Data Sources

All source data were downloaded from the U.S. Census Bureau on October 18, 2026.

- [ACS 2020–2024 table B19013](https://data.census.gov/table/ACSDT5Y2024.B19013): median household income in 2024 inflation-adjusted dollars.
- [Official income bulk file](https://www2.census.gov/programs-surveys/acs/summary_file/2024/table-based-SF/data/5YRData/acsdt5y2024-b19013.dat).
- [2024 county boundary archive, 1:500,000 scale](https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_us_county_500k.zip).

`B19013_E001` is the income estimate; `B19013_M001` is the published 90% margin of error. County income records have identifiers matching `0500000US36` followed by three county-code digits. Removing the prefix `0500000US` produces a five-digit GEOID used to join income to boundaries. State code 36 selects New York boundaries. The statewide reference comes from `0400000US36`, not an average of county medians.

## Reproduce the Analysis

Open `blogpost5_GIS_Visualization.Rproj` in RStudio. Keep the working directory at the project root, not inside `code`.

Install dependencies once if needed:

```r
install.packages(c("sf", "dplyr", "readr", "stringr", "ggplot2", "scales"))
```

Run the analysis:

```r
source("code/blogpost5_all_process.R")
```

Alternatively, from a terminal at the repository root:

```sh
Rscript code/blogpost5_all_process.R
```

The script uses the bundled input files. If an input download is missing, it retrieves that file from the official source; internet access is then required. No Census API key is needed. Results are generated programmatically: tables and spatial data are saved to `data`, and all three PNG figures are saved to `figures`.

## Methods and Interpretation

The analysis checks for 62 unique counties, positive income estimates, and no missing income values after joining. Boundaries are projected to EPSG:32118 for visualization. Both maps use the same statewide income color scale. The NYC-area detail map contains selected counties and is not a complete metropolitan-area definition.

The comparison chart plots selected county estimates with interval endpoints calculated as the estimate plus or minus its published 90% margin of error. The selected counties include the five highest point estimates and four additional counties discussed in the analysis.

This is a descriptive analysis. It does not establish causes, test spatial clustering, or perform formal county-to-county significance tests. County medians hide within-county differences and do not account for household size, local living costs, or wealth. The five-year estimates describe 2020–2024, not 2024 alone.

## Main Findings

Higher income estimates are concentrated on Long Island and north of New York City. Nassau's estimate is $146,202, while the Bronx's is $48,676, a ratio of approximately 3.00. The statewide household median is $85,974. Saratoga ($100,787) provides an example of a higher-income county outside the southeastern concentration. Nearby counties can have substantially different income estimates.

## Related Repositories

- [Analysis repository](https://github.com/liyujing-byte/blogpost5_GIS_Visualization)
- [Published blog post](https://liyujing-byte.github.io/website/blog/posts/post5/)
- [Website repository](https://github.com/liyujing-byte/website)
