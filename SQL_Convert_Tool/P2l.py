import pandas as pd
import re

# 文件路径
mapping_file = "output.xlsx"  # 映射文件
sql_input_file = "input.sql"  # 输入的SQL文件
sql_output_file = "output.sql"  # 替换后的SQL文件
processed_tables_file = "processed_tables.xlsx"  # 处理过的表信息输出文件

# 读取映射文件
df = pd.read_excel(mapping_file)

# 创建映射字典
table_mapping = dict(zip(df["テーブル物理名"], df["テーブル論理名"]))
column_mapping = dict(zip(df["項目物理名"], df["項目論理名"]))

processed_tables = []

def replace_names(sql, table_mapping, column_mapping):
    processed_physical_tables = []

    # 替换表名
    for physical, logical in table_mapping.items():
        physical = str(physical)  # 确保物理名为字符串
        logical = str(logical)   # 确保伦理名为字符串
        if re.search(rf'\b{physical}\b', sql):  # 如果匹配到，记录表信息
            processed_physical_tables.append(physical)  # 只记录物理表名
        sql = re.sub(rf'\b{physical}\b', logical, sql)

    # 替换列名
    for physical, logical in column_mapping.items():
        physical = str(physical)  # 确保物理名为字符串
        logical = str(logical)   # 确保伦理名为字符串
        sql = re.sub(rf'\b{physical}\b', logical, sql)

    return sql, processed_physical_tables


# 读取SQL文件
with open(sql_input_file, "r", encoding="utf-8") as file:
    sql = file.read()

# 替换物理名为伦理名，并记录处理的表
updated_sql, processed_physical_tables = replace_names(sql, table_mapping, column_mapping)

# 写入替换后的SQL到输出文件
with open(sql_output_file, "w", encoding="utf-8") as file:
    file.write(updated_sql)

# 收集处理过的表信息
for physical_table in processed_physical_tables:
    logical_table = table_mapping.get(physical_table, "Unknown")  # 使用 .get() 避免 KeyError
    # 从映射表中查找对应行，获取其他相关信息
    row = df[df["テーブル物理名"] == physical_table]
    description = row["説明"].iloc[0] if "説明" in row.columns and not row.empty else "N/A"
    processed_tables.append({
        "テーブル論理名": logical_table,
        "テーブル物理名": physical_table,
        "説明": description
    })

# 保存处理过的表信息到文件
processed_df = pd.DataFrame(processed_tables)
processed_df.to_excel(processed_tables_file, index=False)

print(f"替换完成！输出的SQL已保存到文件：{sql_output_file}")
print(f"处理过的表信息已保存到文件：{processed_tables_file}")
