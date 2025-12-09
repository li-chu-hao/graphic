#' 将p值转换为显著性符号
#' @param p p值
#' @return 显著性符号字符串
get_signif_label <- function(p) {
  if (is.na(p)) return("NA")
  if (p < 0.001) return("***")
  if (p < 0.01) return("**")
  if (p < 0.05) return("*")
  return("ns")
}

#' 格式化p值显示
#' @param p p值
#' @return 格式化后的p值字符串
format_p_value <- function(p) {
  if (is.na(p)) return("NA")
  if (p < 0.001) return("< 0.001")
  if (p < 0.01) return(sprintf("%.3f", p))
  return(sprintf("%.2f", p))
}

#' 为双因子实验生成显著性标注数据
#' 
#' @param data 输入数据框，必须包含四列：treatment, cell_types, batch, expression
#' @param comparisons 指定要进行的组间比较，默认为NULL（使用所有treatment间的两两比较）
#' @param p_adjust 是否对p值进行多重比较校正，默认为FALSE
#' @param paired 是否进行配对t检验，默认为FALSE
#' @param label_format 标签格式，"p.signif"（星号）或"p.format"（p值），默认为"p.signif"
#' @param y_position_multiplier y轴位置乘数，用于调整标注高度，默认为1.05
#' 
#' @return 包含5列的数据框：cell_types, start, end, y, label
#' @export
generate_signif_data <- function(data, comparisons = NULL, 
                                 x.var=NULL, facet.var=NULL, y.var=NULL, 
                                 p_adjust = FALSE, 
                                 paired = FALSE, label_format = "p.signif",
                                 y_position_multiplier = 1.05) {
  
  if (is.null(x.var)) {
    x.var <- colnames(data)[1]
    facet.var <- colnames(data)[2]
    y.var <- colnames(data)[3]
  }
  
  # 初始化结果数据框
  result_df <- data.frame(
    cell_types = character(),
    start = character(),
    end = character(),
    y = numeric(),
    label = character(),
    stringsAsFactors = FALSE
  )
  
  # 对每个细胞类型进行处理
  for (i.facet in unique(data[[facet.var]])) {
    
    # 筛选当前细胞类型的数据
    cell_data <- data[data[[facet.var]] == i.facet, ]
    
    # 计算每个treatment组的表达量最大值，用于确定y轴位置
    max_vals <- tapply(cell_data[[y.var]], cell_data[[x.var]], max, na.rm = TRUE)
    base_max <- max(cell_data[[y.var]], na.rm = TRUE)
    
    # 进行每个比较
    for (i in seq_along(comparisons)) {
      comp <- comparisons[[i]]
      group1 <- comp[1]
      group2 <- comp[2]
      
      # 提取两个组的数据
      data1 <- cell_data[[y.var]][cell_data[[x.var]] == group1]
      data2 <- cell_data[[y.var]][cell_data[[x.var]] == group2]
      
      # 检查是否有足够的数据进行t检验
      if (length(data1) < 2 || length(data2) < 2) {
        warning(paste("在", i.facet, "中，", group1, "vs", group2, 
                      "的数据不足，跳过比较"))
        next
      }
      
      # 执行t检验
      tryCatch({
        t_test_result <- t.test(data1, data2, paired = paired)
        p_value <- t_test_result$p.value
        
        # 根据指定格式创建标签
        if (label_format == "p.signif") {
          label <- get_signif_label(p_value)
        } else if (label_format == "p.format") {
          label <- format_p_value(p_value)
        } else {
          label <- as.character(p_value)
        }
        
        # 计算y轴位置（基于组内最大值的最大值）
        y_pos <- max(max_vals[group1], max_vals[group2], na.rm = TRUE) * 
          y_position_multiplier * (1 + (i-1)*0.1)  # 为每个比较添加偏移
        
        # 添加到结果数据框
        result_df <- rbind(result_df, data.frame(
          cell_types = i.facet,
          start = group1,
          end = group2,
          y = y_pos,
          label = label,
          stringsAsFactors = FALSE
        ))
        
      }, error = function(e) {
        warning(paste("在", i.facet, "中，", group1, "vs", group2, 
                      "的t检验失败:", e$message))
      })
    }
  }
  
  colnames(result_df) <- c(facet.var, colnames(result_df)[-1])
  
  return(result_df)
}
