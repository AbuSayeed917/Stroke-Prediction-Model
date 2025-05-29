library(shiny)
library(randomForest)
library(caret)
library(glmnet)

# Load saved model and preprocessors
model <- readRDS("best_stroke_model.rds")
training_columns <- readRDS("model_training_columns.rds")
preprocess_obj <- readRDS("preprocessing_obj.rds")
numeric_columns <- readRDS("preprocess_numeric_columns.rds")

# Define UI
ui <- fluidPage(
  titlePanel("Stroke Prediction"),
  sidebarLayout(
    sidebarPanel(
      numericInput("age", "Age", value = 50, min = 1, max = 120),
      selectInput("gender", "Gender", choices = c("Male", "Female")),
      selectInput("ever_married", "Ever Married", choices = c("Yes", "No")),
      selectInput("work_type", "Work Type",
                  choices = c("Private", "Self-employed", "Govt_job", "children", "Never_worked")),
      selectInput("residence_type", "Residence Type", choices = c("Urban", "Rural")),
      numericInput("avg_glucose_level", "Average Glucose Level", value = 100),
      numericInput("bmi", "BMI", value = 25),
      selectInput("smoking_status", "Smoking Status",
                  choices = c("formerly smoked", "never smoked", "smokes", "Unknown")),
      checkboxInput("hypertension", "Hypertension", FALSE),
      checkboxInput("heart_disease", "Heart Disease", FALSE),
      actionButton("submit", "Predict")
    ),
    mainPanel(
      h3("Prediction Result"),
      verbatimTextOutput("result"),
      plotOutput("risk_plot")
    )
  )
)

# Define Server
server <- function(input, output) {
  observeEvent(input$submit, {
    # Step 1: Create raw input dataframe
    df <- data.frame(
      gender = factor(input$gender, levels = c("Female", "Male")),
      age = input$age,
      hypertension = as.integer(input$hypertension),
      heart_disease = as.integer(input$heart_disease),
      ever_married = factor(input$ever_married, levels = c("No", "Yes")),
      work_type = factor(input$work_type, 
                         levels = c("Govt_job", "Never_worked", "Private", "Self-employed", "children")),
      Residence_type = factor(input$residence_type, levels = c("Rural", "Urban")),
      avg_glucose_level = input$avg_glucose_level,
      bmi = input$bmi,
      smoking_status = factor(input$smoking_status,
                              levels = c("Unknown", "formerly smoked", "never smoked", "smokes"))
    )
    
    # Step 2: Create dummy variables
    dummy_df <- as.data.frame(model.matrix(~ . - 1, data = df))
    
    # Step 3: Add missing dummy columns
    missing_cols <- setdiff(training_columns, colnames(dummy_df))
    for (col in missing_cols) {
      dummy_df[[col]] <- 0
    }
    
    # Step 4: Reorder to match training structure
    dummy_df <- dummy_df[, training_columns]
    
    # Step 5: Add missing numeric columns for scaling (if needed)
    for (col in setdiff(numeric_columns, names(dummy_df))) {
      dummy_df[[col]] <- 0
    }
    
    # Step 6: Apply scaling
    dummy_df[, numeric_columns] <- predict(preprocess_obj, dummy_df[, numeric_columns, drop = FALSE])
    
    # Step 7: Make prediction
    prob <- predict(model, newdata = dummy_df, type = "prob")[, "Yes"]
    class <- ifelse(prob > 0.5, "High Risk", "Low Risk")
    
    # Step 8: Output
    output$result <- renderText({
      paste0("Stroke Probability: ", round(prob, 4), "\nRisk Level: ", class)
    })
    
    output$risk_plot <- renderPlot({
      barplot(c(prob, 1 - prob),
              names.arg = c("Stroke", "No Stroke"),
              col = c("red", "green"),
              ylim = c(0, 1),
              main = "Predicted Stroke Risk")
    })
  })
}

# Run the app
shinyApp(ui = ui, server = server)