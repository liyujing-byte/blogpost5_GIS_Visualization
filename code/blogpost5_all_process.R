# Run from the RStudio project root:
# source("code/blogpost5_all_process.R")
required_packages <- c("sf", "dplyr", "readr", "stringr", "ggplot2", "scales")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop("Install missing packages first: ", paste(missing_packages, collapse = ", "))
}

library(sf)
library(dplyr)
library(readr)
library(stringr)
library(ggplot2)

dir.create("data", showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)

# Download the official ACS household income table
income_url <- paste0(
  "https://www2.census.gov/programs-surveys/acs/",
  "summary_file/2024/table-based-SF/data/5YRData/",
  "acsdt5y2024-b19013.dat"
)

if (!file.exists("data/acs2024_b19013.dat")) {
  download.file(
    url = income_url,
    destfile = "data/acs2024_b19013.dat",
    mode = "wb"
  )
}

# Read the table and preserve geographic codes as text
income_all <- read_delim(
  "data/acs2024_b19013.dat",
  delim = "|",
  col_types = cols(.default = col_character())
)

# Keep only New York's 62 counties
ny_income <- income_all |>
  filter(str_detect(GEO_ID, "^0500000US36[0-9]{3}$")) |>
  transmute(
    GEOID = str_remove(GEO_ID, "^0500000US"),
    median_income = as.numeric(B19013_E001),
    margin_of_error = as.numeric(B19013_M001)
  )

# Save the county-level income data
write_csv(ny_income, "data/ny_county_income.csv")

# Check the results
head(ny_income)
nrow(ny_income)

# Download the official 2024 county boundaries
boundary_url <- paste0(
  "https://www2.census.gov/geo/tiger/GENZ2024/shp/",
  "cb_2024_us_county_500k.zip"
)

if (!file.exists("data/county_boundaries_2024.zip")) {
  download.file(
    url = boundary_url,
    destfile = "data/county_boundaries_2024.zip",
    mode = "wb"
  )
}

# Extract the shapefile components when needed
if (!file.exists("data/county_boundaries_2024/cb_2024_us_county_500k.shp")) {
  unzip(
    "data/county_boundaries_2024.zip",
    exdir = "data/county_boundaries_2024"
  )
}

# Read the county boundaries
counties_all <- st_read(
  "data/county_boundaries_2024/cb_2024_us_county_500k.shp",
  quiet = TRUE
)

# Keep only New York counties
ny_counties <- counties_all |>
  filter(STATEFP == "36") |>
  select(GEOID, NAME, geometry)

nrow(ny_counties)

# Join income data to county boundaries
ny_map <- ny_counties |>
  left_join(ny_income, by = "GEOID")

# Validate the joined data
stopifnot(
  nrow(ny_map) == 62,
  !anyDuplicated(ny_map$GEOID),
  !anyNA(ny_map$median_income),
  all(ny_map$median_income > 0)
)

# Inspect county names and income values
ny_map |>
  st_drop_geometry() |>
  select(NAME, GEOID, median_income) |>
  head()

# Project the boundaries for mapping
ny_map_projected <- st_transform(ny_map, crs = 32118)

# Create the main income map
income_map <- ggplot(ny_map_projected) +
  geom_sf(
    aes(fill = median_income),
    color = "white",
    linewidth = 0.25
  ) +
  scale_fill_viridis_c(
    option = "viridis",
    breaks = c(50000, 75000, 100000, 125000, 145000),
    labels = scales::label_dollar(
      scale = 0.001,
      suffix = "k"
    ),
    name = "Median household income",
    guide = guide_colorbar(
      title.position = "top",
      barwidth = grid::unit(12, "cm"),
      barheight = grid::unit(0.4, "cm")
    )
  ) +
  labs(
    title = "Household Income Across New York Counties",
    subtitle = "ACS 2020–2024 five-year estimates",
    caption = paste(
      "Source: U.S. Census Bureau, ACS table B19013;",
      "2024 cartographic county boundaries.",
      "Income in 2024 dollars. Colors show county point estimates.",
      sep = "\n"
    )
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.title = element_text(
      face = "bold",
      size = 18
    ),
    plot.subtitle = element_text(
      margin = margin(b = 12)
    ),
    legend.position = "bottom",
    plot.caption = element_text(
      hjust = 0,
      size = 9,
      margin = margin(t = 12)
    ),
    plot.margin = margin(15, 20, 15, 20)
  )

# Display the map
if (interactive()) print(income_map)

# Save the main map at a fixed size
ggsave(
  filename = "figures/income_map.png",
  plot = income_map,
  width = 11,
  height = 8,
  units = "in",
  dpi = 300,
  bg = "white"
)

# Save the joined spatial dataset
saveRDS(
  ny_map_projected,
  file = "data/ny_county_income_map.rds"
)

# Confirm that both files were saved
file.exists("figures/income_map.png")
file.exists("data/ny_county_income_map.rds")

# Create a county-level table without map geometry
county_summary <- ny_map |>
  st_drop_geometry() |>
  select(NAME, GEOID, median_income, margin_of_error) |>
  arrange(desc(median_income))

# Show the five highest county estimates
head(county_summary, 5)

# Show the five lowest county estimates
county_summary |>
  arrange(median_income) |>
  head(5)

# Save the complete table
write_csv(
  county_summary,
  "data/county_income_summary.csv"
)

# Extract the published statewide estimate
state_income <- income_all |>
  filter(GEO_ID == "0400000US36") |>
  transmute(
    median_income = as.numeric(B19013_E001),
    margin_of_error = as.numeric(B19013_M001)
  )

state_income

# Summarize the county income range
income_comparison <- county_summary |>
  summarise(
    highest_income = max(median_income),
    lowest_income = min(median_income),
    dollar_gap = highest_income - lowest_income,
    highest_to_lowest_ratio = highest_income / lowest_income
  )

income_comparison

# Save the results
write_csv(
  state_income,
  "data/state_income.csv"
)

write_csv(
  income_comparison,
  "data/income_comparison.csv"
)

# Select counties for the NYC-area detail map
detail_counties <- c(
  "Bronx",
  "Kings",
  "New York",
  "Queens",
  "Richmond",
  "Nassau",
  "Westchester",
  "Rockland"
)

nyc_detail <- ny_map_projected |>
  filter(NAME %in% detail_counties)

# Check that all eight counties were selected
stopifnot(nrow(nyc_detail) == 8)

# Create readable map labels
nyc_detail <- nyc_detail |>
  mutate(
    map_label = case_when(
      NAME == "Kings" ~ "Brooklyn (Kings)",
      NAME == "New York" ~ "Manhattan (New York)",
      NAME == "Richmond" ~ "Staten Island (Richmond)",
      TRUE ~ NAME
    )
  )

# Use the statewide income range for consistent colors
statewide_limits <- range(
  ny_map_projected$median_income,
  na.rm = TRUE
)

# Create the detail map
nyc_detail_map <- ggplot(nyc_detail) +
  geom_sf(
    aes(fill = median_income),
    color = "white",
    linewidth = 0.4
  ) +
  geom_sf_label(
    aes(label = map_label),
    fill = "white",
    color = "black",
    size = 3,
    label.padding = grid::unit(0.15, "lines"),
    show.legend = FALSE
  ) +
  scale_fill_viridis_c(
    limits = statewide_limits,
    breaks = c(50000, 75000, 100000, 125000, 145000),
    labels = scales::label_dollar(
      scale = 0.001,
      suffix = "k"
    ),
    name = "Median household income",
    guide = guide_colorbar(
      title.position = "top",
      barwidth = grid::unit(12, "cm"),
      barheight = grid::unit(0.4, "cm")
    )
  ) +
  labs(
    title = "Income Differences Across Nearby Counties",
    subtitle = "Selected NYC-area counties | ACS 2020–2024",
    caption = paste(
      "Source: U.S. Census Bureau, ACS B19013 and 2024 county boundaries.",
      "Income in 2024 dollars. Same color scale as the statewide map.",
      "Selected counties only; not the full metropolitan area.",
      sep = "\n"
    )
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 17),
    plot.subtitle = element_text(margin = margin(b = 12)),
    legend.position = "bottom",
    plot.caption = element_text(
      hjust = 0,
      size = 9,
      margin = margin(t = 12)
    ),
    plot.margin = margin(15, 20, 15, 20)
  )

if (interactive()) print(nyc_detail_map)

# Save the detail map with a wider layout
ggsave(
  filename = "figures/nyc_detail.png",
  plot = nyc_detail_map,
  width = 12,
  height = 10,
  units = "in",
  dpi = 300,
  bg = "white"
)

# Select counties discussed in the article
comparison_counties <- c(
  "Nassau", "Suffolk", "Putnam",
  "Westchester", "Rockland",
  "Saratoga", "Chautauqua",
  "Cattaraugus", "Bronx"
)

# Calculate 90% confidence interval endpoints
comparison_data <- county_summary |>
  filter(NAME %in% comparison_counties) |>
  mutate(
    lower_bound = median_income - margin_of_error,
    upper_bound = median_income + margin_of_error
  )

# Plot county estimates and uncertainty
comparison_plot <- ggplot(
  comparison_data,
  aes(
    x = median_income,
    y = reorder(NAME, median_income)
  )
) +
  geom_vline(
    xintercept = state_income$median_income,
    linetype = "dashed",
    color = "gray50"
  ) +
  geom_segment(
    aes(
      x = lower_bound,
      xend = upper_bound,
      yend = reorder(NAME, median_income)
    ),
    linewidth = 0.8,
    color = "#287A8E"
  ) +
  geom_point(size = 3, color = "#253B53") +
  scale_x_continuous(
    labels = scales::label_dollar()
  ) +
  labs(
    title = "Household Income in Selected New York Counties",
    subtitle = "Points: income estimates | Lines: 90% confidence intervals",
    x = "Median household income (2024 dollars)",
    y = NULL,
    caption = paste(
      "Source: U.S. Census Bureau, ACS 2020–2024, B19013.",
      "Dashed line: statewide household median income.",
      "Selected counties only; not a complete ranking.",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 16),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    plot.caption = element_text(
      hjust = 0,
      margin = margin(t = 12)
    ),
    plot.margin = margin(15, 20, 15, 20)
  )

# Display and save the figure
if (interactive()) print(comparison_plot)

ggsave(
  filename = "figures/county_comparison.png",
  plot = comparison_plot,
  width = 10,
  height = 6.5,
  units = "in",
  dpi = 300,
  bg = "white"
)

# Save the plotted data
write_csv(
  comparison_data,
  "data/comparison_counties.csv"
)
