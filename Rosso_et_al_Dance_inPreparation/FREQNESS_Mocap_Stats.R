# Load required libraries
library(readxl)
library(dplyr)
library(ggplot2)
library(ggpubr)
library(lme4)
library(lmerTest)  # Enables p-values via Satterthwaite approximation

# CHOOSE DEPENDENT VARIABLE
dv <- "Mirror"  # Options: "RR", "DET", "Mirror"

# Set path to your Excel file
data <- read_excel("/Users/au658766/Documents/MIB/Projects/NESS_withLBPD/2025_FreqNESS_Mocap/OUT2R_Comp#2.xlsx")

# Filter to retain only one Meter level
data_m1 <- data %>%
  filter(Meter == "M4")

# Convert Visual and Music to factors
data_m1$Visual <- factor(data_m1$Visual)
data_m1$Music <- factor(data_m1$Music)
data_m1$Meter <- factor(data_m1$Meter)

# Compute summary stats for plot
summary_stats <- data_m1 %>%
  group_by(Visual, Music) %>%
  summarise(mean = mean(.data[[dv]]), sem = sd(.data[[dv]])/sqrt(n()), .groups = 'drop')

# Plot 1: Bar + SEM
ggplot(summary_stats, aes(x = Music, y = mean, fill = Visual)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
  geom_errorbar(aes(ymin = mean - sem, ymax = mean + sem),
                position = position_dodge(width = 0.8), width = 0.2) +
  labs(title = paste("Mean ± SEM for Meter M1 -", dv),
       y = dv, x = "Music", fill = "Visual") +
  theme_minimal() +
  scale_fill_manual(values = c("No" = "#990000", "Yes" = "#003399"))

# Plot 2: Line + SEM
ggplot(summary_stats, aes(x = Music, y = mean, group = Visual, color = Visual)) +
  geom_line(size = 1.2) +
  geom_point(size = 4) +
  geom_errorbar(aes(ymin = mean - sem, ymax = mean + sem),
                width = 0.15, size = 0.7) +
  labs(title = paste("Mean ± SEM for Meter M1 -", dv),
       x = "Music", y = dv, color = "Visual") +
  theme_minimal(base_size = 14) +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"), legend.position = "right") +
  scale_color_manual(values = c("No" = "#990000", "Yes" = "#003399"))

# Apply log transformation (optional), only if dv is not "Mirror"
if (dv != "Mirror") {
  data[[dv]] <- log(data[[dv]])
  data_m1[[dv]] <- log(data_m1[[dv]])
}

# Mixed-effects model: M1 only
lmm_posthoc <- lmer(as.formula(paste(dv, "~ Visual * Music + (1 | Dyad)")), data = data_m1)
summary(lmm_posthoc)
anova(lmm_posthoc, type = 3)


################################


# Mixed-effects model: full dataset with Meter factor
lmm_factorial <- lmer(as.formula(paste(dv, "~ Visual * Music * Meter + (1 | Dyad)")), data = data)
summary(lmm_factorial)
anova(lmm_factorial, type = 3)

# Residual analysis
residuals_lmm <- residuals(lmm_posthoc)
residuals_lmm_factorial <- residuals(lmm_factorial)

hist(residuals_lmm, main = "Histogram of Residuals", xlab = "Residuals")
hist(residuals_lmm_factorial, main = "Histogram of Residuals", xlab = "Residuals")

qqnorm(residuals_lmm)
qqline(residuals_lmm, col = "red")
qqnorm(residuals_lmm_factorial)
qqline(residuals_lmm_factorial, col = "red")

shapiro.test(residuals_lmm)
shapiro.test(residuals_lmm_factorial)

plot(fitted(lmm_posthoc), residuals_lmm, xlab = "Fitted values", ylab = "Residuals", main = "Residuals vs Fitted")
abline(h = 0, col = "red")
plot(fitted(lmm_factorial), residuals_lmm_factorial, xlab = "Fitted values", ylab = "Residuals", main = "Residuals vs Fitted")
abline(h = 0, col = "red")

# Polynomial modeling of Meter
data$MeterNum <- as.numeric(gsub("[^0-9]", "", data$Meter))
data$Visual <- factor(data$Visual)
data$Music <- factor(data$Music)
data$Dyad <- factor(data$Dyad)

lmm_line <- lmer(as.formula(paste(dv, "~ Visual * Music * MeterNum + (1 | Dyad)")), data = data)
lmm_quad <- lmer(as.formula(paste(dv, "~ Visual * Music * poly(MeterNum, 2) + (1 | Dyad)")), data = data)
lmm_cubc <- lmer(as.formula(paste(dv, "~ Visual * Music * poly(MeterNum, 3) + (1 | Dyad)")), data = data)

anova(lmm_line, lmm_quad, lmm_cubc)
anova(lmm_cubc)

# Residuals diagnostics for all three models
residuals_lmm_line <- residuals(lmm_line)
residuals_lmm_quad <- residuals(lmm_quad)
residuals_lmm_cubc <- residuals(lmm_cubc)

fitted_lmm_line <- fitted(lmm_line)
fitted_lmm_quad <- fitted(lmm_quad)
fitted_lmm_cubc <- fitted(lmm_cubc)

par(mfrow = c(1, 3))
hist(residuals_lmm_line, main = "Linear: Residuals", xlab = "Residuals")
hist(residuals_lmm_quad, main = "Quadratic: Residuals", xlab = "Residuals")
hist(residuals_lmm_cubc, main = "Cubic: Residuals", xlab = "Residuals")

par(mfrow = c(1, 3))
qqnorm(residuals_lmm_line, main = "QQ: Linear")
qqline(residuals_lmm_line, col = "red")
qqnorm(residuals_lmm_quad, main = "QQ: Quadratic")
qqline(residuals_lmm_quad, col = "red")
qqnorm(residuals_lmm_cubc, main = "QQ: Cubic")
qqline(residuals_lmm_cubc, col = "red")

cat("Shapiro-Wilk Test:\n")
cat("Linear model:\n"); print(shapiro.test(residuals_lmm_line))
cat("Quadratic model:\n"); print(shapiro.test(residuals_lmm_quad))
cat("Cubic model:\n"); print(shapiro.test(residuals_lmm_cubc))

par(mfrow = c(1, 3))
plot(fitted_lmm_line, residuals_lmm_line, xlab = "Fitted values", ylab = "Residuals", main = "Linear: Residuals vs Fitted")
abline(h = 0, col = "red")
plot(fitted_lmm_quad, residuals_lmm_quad, xlab = "Fitted values", ylab = "Residuals", main = "Quadratic: Residuals vs Fitted")
abline(h = 0, col = "red")
plot(fitted_lmm_cubc, residuals_lmm_cubc, xlab = "Fitted values", ylab = "Residuals", main = "Cubic: Residuals vs Fitted")
abline(h = 0, col = "red")

par(mfrow = c(1, 1))
