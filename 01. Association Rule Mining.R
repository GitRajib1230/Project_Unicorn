# 703 Group Project
# Group A1

# Install libraries if not already installed
required_packages <- c("dplyr", "tidyr", "arules", "ggplot2", "arulesViz")

# Check and install missing packages
new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages)

# Load necessary libraries
library(dplyr)      # For data manipulation
library(tidyr)      # For data tidying and unnesting
library(arules)     # For association rule mining
library(ggplot2)    # For data visualization
library(arulesViz)  # For visualizing association rules

# Step 1: Read the dataset
data_association <- read.csv("BUSINFO_703_Dataset_Unicorns_$2B_(508x7).csv")

# Step 2: Select relevant columns for analysis (Company and Select.Investors)
data_sub <- data_association[, c("Company", "Select.Investors")]

# Step 3: Split the 'Select.Investors' column by commas and unnest to create a long-format data frame
data_arranged <- data_sub %>% 
  mutate(Select.Investors = strsplit(as.character(Select.Investors), ", ")) %>% 
  unnest(Select.Investors)

# Step 4: Clean the data by removing rows with empty or missing values in 'Select.Investors'
data_clean <- data_arranged[data_arranged$Select.Investors != "", ]  # Remove empty strings
data_clean <- data_arranged[!is.na(data_arranged$Select.Investors), ]  # Remove NA values

# Step 5: Create a list of investors grouped by company
data_list <- split(data_clean$Select.Investors, data_clean$Company)

# Step 6: Convert the list into transaction format for association rule mining
data_txn <- as(data_list, "transactions")

# Step 7: View a summary of the transactions
summary(data_txn)

# Step 8: Set a minimum support threshold and generate frequent itemsets
min_support = 0.001  # Support threshold
itemsets <- apriori(data_txn,
                    parameter = list(supp = min_support,
                                     target = "frequent itemsets")
)
# View the frequent itemsets
inspect(itemsets)

# Step 9: Plot the item frequency for the top 5 most frequent items
itemFrequencyPlot(data_txn, topN = 5)

# Step 10: Set a minimum confidence threshold and generate association rules
min_confidence = 0.01  # Confidence threshold
rules <- apriori(data_txn, parameter = (
  list(supp = min_support,
       conf = min_confidence,
       target = "rules")
)
)
# View the generated rules
inspect(rules)

# Step 11: Analyze how the number of itemsets changes with different support thresholds
df_support <- data.frame(support = numeric(), count = numeric())  # Initialize an empty data frame
for (i in seq(1, 0.001, -0.001)) {  # Loop through support values from 1 to 0.001
  print(i)  # Print the current support threshold
  itemsets <- apriori(data_txn,
                      parameter = list(supp = i,
                                       target = "frequent itemsets"))
  itemsets_count <- length(itemsets)  # Count the number of itemsets
  df_support <- rbind(df_support,
                      data.frame(support = i,
                                 count = itemsets_count))  # Append results to data frame
}

# Step 12: Plot the relationship between support threshold and number of itemsets
ggplot(df_support, aes(x = support, y = count)) +
  geom_line() +
  geom_point() +
  scale_x_reverse() +  # Reverse the x-axis for clarity
  geom_hline(yintercept = 30, linetype = "dashed") + # Add a horizontal line at y = 30
  geom_vline(xintercept = 0.06, linetype = "dashed") + # Add a vertical line at x = 0.06
  labs(title = "Number of Itemsets vs Support Threshold",
       x = "Support Threshold",
       y = "Number of Itemsets")

# Step 13: Filter the rules based on lift, support, and confidence thresholds
fin_rules <- subset(rules, lift > 1 & support > 0.007 & confidence > 0.05)

# View the filtered rules
inspect(fin_rules)

# Sort the filtered rules by lift
sorted_rules <- sort(fin_rules, by = "lift")

# View the sorted rules
inspect(sorted_rules)

# Convert the filtered rules into a data frame and sort by lift and confidence in descending order
df_fin_rules <- as(fin_rules, "data.frame")
df_fin_rules_sorted <- df_fin_rules[order(-df_fin_rules$lift, -df_fin_rules$confidence), ]

# Step 14: Visualize the filtered rules
plot(fin_rules)  # Scatter plot of the rules
plot(fin_rules, method = "graph")  # Network visualization of the rules

# Load the plotly library
library(plotly)

# Extract support, confidence, and lift from the rules
rules_metrics <- data.frame(
  support = quality(fin_rules)$support,
  confidence = quality(fin_rules)$confidence,
  lift = quality(fin_rules)$lift
)

# Create a 3D scatter plot with plotly
plot_ly(
  data = rules_metrics,
  x = ~support,
  y = ~confidence,
  z = ~lift,
  type = "scatter3d",
  mode = "markers",
  marker = list(size = 5, color = ~lift, colorscale = "Viridis", showscale = TRUE)
) %>%
  layout(
    title = "3D Visualization of Association Rules",
    scene = list(
      xaxis = list(title = "Support"),
      yaxis = list(title = "Confidence"),
      zaxis = list(title = "Lift")
    )
  )


