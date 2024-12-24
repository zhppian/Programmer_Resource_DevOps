import pandas as pd

# 元のExcelファイル
input_file = "input.xlsm"
# 統合結果を保存するファイル
output_file = "output.xlsx"

def consolidate_sheets(input_file, output_file):
    # Excelファイルを読み込み
    excel_data = pd.ExcelFile(input_file)
    consolidated_data = pd.DataFrame(columns=["物理名", "論理名", "シート名", "備考"])

    # 各シートのデータを処理
    for sheet_name in excel_data.sheet_names:
        # 現在のシートをDataFrameとして読み込む
        sheet_data = pd.read_excel(input_file, sheet_name=sheet_name, header=None)
        # B列 (1), C列 (2), J列 (10) が存在するか確認
        if sheet_data.shape[1] > 10:  # 列数が11以上であることを確認
            # B7以降とC7以降を取得（行番号は0ベースなので6行目以降）
            physical_names = sheet_data.iloc[6:, 1]  # B列
            logical_names = sheet_data.iloc[6:, 2]  # C列
            comments = sheet_data.iloc[6:, 11]  # J列
        else:
            print(f"スキップ: {sheet_name} (必要な列が不足しています)")
            continue

        # データフレームに追加
        temp_df = pd.DataFrame({
            "物理名": logical_names,
            "論理名": physical_names,
            "シート名": sheet_name,  
            "備考": comments  

        })

        # 統合用データフレームに追加
        consolidated_data = pd.concat([consolidated_data, temp_df], ignore_index=True)

    # 統合したデータを新しいExcelファイルに保存
    consolidated_data.to_excel(output_file, index=False)
    print(f"統合が完了しました: {output_file}")

# 実行
consolidate_sheets(input_file, output_file)
