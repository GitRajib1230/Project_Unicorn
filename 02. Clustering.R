# BUSINFO 703
# Group A1


# Setting Environment ----
## Load necessary libraries
library(dplyr)
library(readxl)
library(factoextra)
library(cluster)
library(ggplot2)
library(caret)
library(plotly)

## Check Working Directory
getwd()

# Association Rule Mining ----



# Cluster Analysis ----

## Load data (replace 'output_file_v.csv' with your file path)
data <- read.csv("CrunchBase_Final_Data.csv", stringsAsFactors = FALSE)

## Handle `""` values as NA
data[data == ""] <- NA

## Filter for 'United States' and 'Enterprise Tech'
data2 <- data %>%
  filter(Country == "United States") %>%
  filter(Industry == "Enterprise Tech")

## Variables of interest
cols_of_interest <- c("Valuation", "Number.of.Investors", "Website.Monthly.Visits", "Trademark.registered")

## Select only the required columns
data2 <- data2 %>%
  select(all_of(cols_of_interest))

## Convert numeric-like object columns to numeric
numeric_cols <- c("Valuation", "Number.of.Investors", "Website.Monthly.Visits", "Trademark.registered")

data2[numeric_cols] <- lapply(data2[numeric_cols], function(x) {
  as.numeric(gsub(",", "", x))  # Remove commas and convert to numeric
})

## Handle missing values by imputing with column means
data2 <- data2 %>%
  mutate(across(everything(), ~ ifelse(is.na(.), mean(., na.rm = TRUE), .)))

## Remove constant or near-constant columns
constant_cols <- sapply(data2, function(x) var(x, na.rm = TRUE) == 0 | is.na(var(x, na.rm = TRUE)))
if (any(constant_cols)) {
  cat("Removing constant columns:", names(data2)[constant_cols], "\n")
  data2 <- data2[, !constant_cols]
}

## Standardize the data for PCA
scaled_data <- scale(data2)

## Perform PCA
pca_result <- prcomp(scaled_data, center = TRUE, scale. = TRUE)

## Visualize explained variance to choose number of components
fviz_eig(pca_result, addlabels = TRUE, ylim = c(0, 100)) +
  ggtitle("Explained Variance by Principal Components")



## Choose components that explain ~80-90% variance
pca_data <- pca_result$x[, 1:which(cumsum(pca_result$sdev^2 / sum(pca_result$sdev^2)) > 0.8)[1]]

## Determine the optimal number of clusters using the Elbow Method
fviz_nbclust(pca_data, kmeans, method = "wss") + 
  ggtitle("Elbow Method for Optimal Clusters")
              # As per Elbow Plot, 4 is the optimal cluster

## Perform K-Means Clustering (choose k based on Elbow Method; e.g., k = 4)
set.seed(123)  # For reproducibility
kmeans_result <- kmeans(pca_data, centers = 4, nstart = 25)

## Add cluster labels to the filtered dataset (data2)
data2$Cluster <- kmeans_result$cluster

## Map cluster labels back to the original dataset using matching row indices
data$Cluster <- NA 
data$Cluster[data$Country == "United States" & data$Industry == "Enterprise Tech"] <- data2$Cluster

## Visualize clusters in PCA dimensions
fviz_cluster(kmeans_result, data = pca_data, geom = "point", ellipse = TRUE) +
  ggtitle("Cluster Visualization using PCA Components")

## Create a PCA biplot
fviz_pca_biplot(pca_result, 
                geom = c("point", "arrow"), 
                habillage = data2$Cluster, 
                addEllipses = TRUE, 
                ellipse.level = 0.8) +
  ggtitle("PCA Biplot with Clusters") +
  theme_minimal()

## Summarize clusters by mean values of key features
cluster_summary <- data2 %>%
  group_by(Cluster) %>%
  summarize(across(all_of(numeric_cols), mean, na.rm = TRUE))

## Print cluster summary ----
print(cluster_summary)

## Save cluster assignments and updated dataset
write.csv(data, "Clustered_Unicorns.csv", row.names = FALSE)
write.csv(data2, "Clustered_Unicorns_Filtered.csv", row.names = FALSE)

## Visualize clusters with ggplot2
cluster_viz <- data.frame(
  PCA1 = pca_data[, 1],  # First Principal Component
  PCA2 = pca_data[, 2],  # Second Principal Component
  Cluster = as.factor(kmeans_result$cluster)  # Cluster assignments
)

## Visualize Cluster using PCA Components
ggplot(cluster_viz, aes(x = PCA1, y = PCA2, color = Cluster)) +
  geom_point(size = 3, alpha = 0.8) +
  scale_color_brewer(palette = "Set1") +  # Use a color palette for distinction
  labs(
    title = "Cluster Visualization using PCA Components",
    x = "Principal Component 1",
    y = "Principal Component 2",
    color = "Cluster"
  ) +
  theme_minimal()

## Visualize explained variance by PCA components
### Create DataFrame
explained_variance <- data.frame(
  Components = seq_along(pca_result$sdev),
  Variance = (pca_result$sdev^2 / sum(pca_result$sdev^2)) * 100,
  CumulativeVariance = cumsum(pca_result$sdev^2 / sum(pca_result$sdev^2)) * 100
)

### Create visualization 
ggplot(explained_variance, aes(x = Components)) +
  geom_bar(aes(y = Variance), stat = "identity", fill = "skyblue", alpha = 0.8) +
  geom_line(aes(y = CumulativeVariance, group = 1), color = "red", size = 1) +
  geom_point(aes(y = CumulativeVariance), color = "red", size = 2) +
  labs(
    title = "PCA Explained Variance",
    x = "Principal Components",
    y = "Variance Explained (%)"
  ) +
  scale_x_continuous(breaks = seq_along(pca_result$sdev)) +
  theme_minimal()

## Calculate Average Silhouette scores for k = 3 to 6
silhouette_scores <- sapply(3:6, function(k) {
  km <- kmeans(pca_data, centers = k, nstart = 25)
  sil <- silhouette(km$cluster, dist(pca_data))
  mean(sil[, 3])  # Average silhouette width
})

## Create a data frame for silhouette scores
silhouette_df <- data.frame(
  Clusters = 3:6,
  AverageSilhouette = silhouette_scores
)

## Audit Silhouette Score ----
ggplot(silhouette_df, aes(x = factor(Clusters), y = AverageSilhouette)) +
  geom_bar(stat = "identity") +  # Use stat = "identity" for a bar plot with specific values
  labs(
    title = "Average Silhouette Scores by Cluster",
    x = "Clusters",
    y = "Average Silhouette Score",
    fill = "Cluster"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5),  # Center-align the title
    axis.title.x = element_blank()  # Remove the x-axis title if preferred
  )


## Auditing cluster in 3D model ----
### Performing PCA (same PCA object from the previous steps)
pca_data_3d <- pca_result$x[, 1:3]  # Select the first three principal components

### Create a data frame for plotting
pca_3d_data <- data.frame(
  PCA1 = pca_data_3d[, 1],
  PCA2 = pca_data_3d[, 2],
  PCA3 = pca_data_3d[, 3],
  Cluster = as.factor(data2$Cluster)  # Cluster labels
)

### Create a 3D scatter plot using plotly
pca_3d_plot <- plot_ly(pca_3d_data, 
                       x = ~PCA1, y = ~PCA2, z = ~PCA3, 
                       color = ~Cluster, 
                       colors = c('red', 'blue', 'green', 'purple'), 
                       type = 'scatter3d', 
                       mode = 'markers') %>%
  layout(title = "3D PCA Plot with Clusters",
         scene = list(
           xaxis = list(title = "Principal Component 1"),
           yaxis = list(title = "Principal Component 2"),
           zaxis = list(title = "Principal Component 3")
         ))

### Show the plot ----
pca_3d_plot

## Visualize Cluster Profiles as per Active Variables ----
### Boxplot for a specific variable

#### Clusters by Valuation
ggplot(data2, aes(x = factor(Cluster), y = Valuation, fill = factor(Cluster))) +
  geom_boxplot() +
  labs(title = "Clusters by Valuation of the Companies", 
       x = NULL,  # Removes the x-axis title
       y = "Valuation", 
       fill = "Cluster") +
  scale_fill_manual(values = c(
    "lightblue",  # Blue for "Emerging Unicorns"
    "lightgreen",  # Green for "High-Value Growth Leaders"
    "lightcoral",  # Orange for "Established Titans"
    "orange"   # Yellow for "Intellectual Property Champions"
  ), labels = c("1. Emerging Unicorns", 
                "2. High-Value Growth Leaders", 
                "3. Established Titans", 
                "4. Intellectual Property Champions")) +
  theme_minimal()

#### Clusters by Website.Monthly.Visit
ggplot(data2, aes(x = factor(Cluster), y = Website.Monthly.Visits/1000000, fill = factor(Cluster))) +
  geom_boxplot() +
  labs(title = "Clusters by Website Monthly Visit", 
       x = NULL,  # Removes the x-axis title
       y = "Website Monthly Visit (Million Times)", 
       fill = "Cluster") +
  scale_fill_manual(values = c(
    "lightblue",  # Blue for "Emerging Unicorns"
    "lightgreen",  # Green for "High-Value Growth Leaders"
    "lightcoral",  # Orange for "Established Titans"
    "orange"   # Yellow for "Intellectual Property Champions"
  ), labels = c("1. Emerging Unicorns", 
                "2. High-Value Growth Leaders", 
                "3. Established Titans", 
                "4. Intellectual Property Champions")) +
  theme_minimal()

#### Clusters by Number.of.Investors
ggplot(data2, aes(x = factor(Cluster), y = Number.of.Investors, fill = factor(Cluster))) +
  geom_boxplot() +
  labs(title = "Clusters by Number of Investors", 
       x = NULL,  # Removes the x-axis title
       y = "Number of Investors", 
       fill = "Cluster") +
  scale_fill_manual(values = c(
    "lightblue",  # Blue for "Emerging Unicorns"
    "lightgreen",  # Green for "High-Value Growth Leaders"
    "lightcoral",  # Orange for "Established Titans"
    "orange"   # Yellow for "Intellectual Property Champions"
  ), labels = c("1. Emerging Unicorns", 
                "2. High-Value Growth Leaders", 
                "3. Established Titans", 
                "4. Intellectual Property Champions")) +
  theme_minimal()

#### Clusters by Valuation Trademark.Registered
ggplot(data2, aes(x = factor(Cluster), y = Trademark.registered, fill = factor(Cluster))) +
  geom_boxplot() +
  labs(title = "Clusters by Trademark Registered", 
       x = NULL,  # Removes the x-axis title
       y = "Number of Trademark Registered", 
       fill = "Cluster") +
  scale_fill_manual(values = c(
    "lightblue",  # Blue for "Emerging Unicorns"
    "lightgreen",  # Green for "High-Value Growth Leaders"
    "lightcoral",  # Orange for "Established Titans"
    "orange"   # Yellow for "Intellectual Property Champions"
  ), labels = c("1. Emerging Unicorns", 
                "2. High-Value Growth Leaders", 
                "3. Established Titans", 
                "4. Intellectual Property Champions")) +
  theme_minimal()

### Show the plot again ----
pca_3d_plot