# インシデントNo.69 S3リクエスト制限超過対応 リリース時データ移行手順書  

## 概要  
本対応でstorage用バケット格納するファイルのパスが以下のように変更となる。  
```
<変更前>
{{asset_location_key}}
```
```
<変更後>
{{asset_id}}/{{asset_location_key}}
```
そのため、本対応リリース前に登録されたファイルの格納先を変更後のパスへ変更する必要があるため、本作業にて既に登録されているファイルのパスを変更する作業を実施する。  

## 前提条件・制約事項
### 前提条件
- AWS CLIが利用できること
- 対象環境へのAWSアカウントを保持していること
- 対象環境へのクレデンシャルを保持していること

### 制約事項  
作業実施中に新たにファイルが登録されてしまうと移行対象から外れてしまい、リリース後のアセット操作でエラーが発生してしまうため、作業実施中に以下の操作を制限する必要がある。  
- アップロード  （単体、フォルダ、ZIP自動解凍）
- コピー
- ゲストアップロード（単体、フォルダ、ZIP自動解凍）

## 事前作業  
### 移行対象アセット情報抽出  
1. 対象環境のAWSコンソールを開く。  
2. Amazon RDSへ移動し、クエリエディタを開く。  
3. エディタに以下のSQLの入力し、実行ボタンを押下する。  
  ```SQL
  with recursive assets (root_parent_id, asset_id, asset_type, asset_name, data_size) as (
        select
            parent_id as root_parent_id,
            asset_id,
            asset_type,
            asset_name,
            data_size
        from
            asset_info a
        where
            del_flag = false
        and parent_type IN ('SUBJECT', 'THEME')
        and (exists (select
                         *
                     from
                         brand b,
                         subject s,
                         layout l,
                         theme t
                     where
                         b.del_flag = false
                       --and b.brand_id = '16e575e8-0448-48fc-a192-75bd6baac2df'
                     and b.brand_id = s.brand_id
                     and s.del_flag = false
                     and s.subject_id = l.subject_id
                     and l.del_flag = false
                     and l.layout_id = t.layout_id
                     and t.del_flag = false
                     and t.theme_id = a.parent_id) or
             exists (select
                         *
                     from
                         brand b,
                         subject s
                     where
                         b.del_flag = false
                       --and b.brand_id = '16e575e8-0448-48fc-a192-75bd6baac2df'
                     and b.brand_id = s.brand_id
                     and s.del_flag = false
                     and s.subject_id = a.parent_id))
        UNION ALL
        select
            p.root_parent_id,
            c.asset_id,
            c.asset_type,
            c.asset_name,
            c.data_size
        from
            asset_info c,
            assets p
        where
          c.del_flag = false
      and c.parent_id = p.asset_id
  )
  select
      b.brand_id,
      b.brand_name,
      sum(case when a.asset_type = 'DIRECTORY' then 1 else 0 end) as directory_count,
      sum(case when a.asset_type = 'FILE' then 1 else 0 end) as file_count,
      sum(a.data_size) as used
  from
      brand b,
      subject s,
      layout l,
      theme t,
      assets a
  where
      b.del_flag = false
  and b.brand_id = s.brand_id
  and s.del_flag = false
  and s.subject_id = l.subject_id
  and l.del_flag = false
  and l.layout_id = t.layout_id
  and t.del_flag = false
  and (t.theme_id = a.root_parent_id or s.subject_id = a.root_parent_id)
  --and a.asset_type = 'FILE'
  group by
      b.brand_id,
      b.brand_name
  ;
  ```
4. 出力に表示されたfile_count項目の値を控える。  
5. 4で控えた件数分offsetの値を変更し、エディタに以下のSQLを入力し、実行ボタンを押下して表示された結果をExport to csvで取得する。  
   （1回目offset 0、2回目offset 2000、3回目offset 4000・・・）
  ```SQL
  WITH RECURSIVE child(path, root_parent_id, asset_name, asset_id, asset_type, parent_id, asset_location_key) as(
      SELECT
          '' || asset_name,
          parent_id as root_parent_id,
          asset_name,
          asset_id,
          asset_type,
          parent_id,
          asset_location_key
      FROM
          asset_info
      WHERE
          parent_type IN ('SUBJECT', 'THEME')
      AND del_flag = 'f'
      UNION ALL
      SELECT
          child.path || '/' || asset_info.asset_name,
          child.root_parent_id as root_parent_id,
          asset_info.asset_name,
          asset_info.asset_id,
          asset_info.asset_type,
          asset_info.parent_id,
          asset_info.asset_location_key
      FROM
          asset_info,
          child
      WHERE
          asset_info.parent_id = child.asset_id
      AND asset_info.del_flag = 'f'
  )
  SELECT
      b.brand_id,
      b.brand_name,
      s.subject_name,
      l.layout_name,
      t.theme_name,
      a.path,
      a.asset_name,
      a.asset_id,
      a.asset_location_key
  FROM
      brand b,
      subject s,
      layout l,
      theme t,
      child a
  WHERE
      del_flag = false
  and b.brand_id = s.brand_id
  and s.del_flag = false
  and s.subject_id = l.subject_id
  and l.del_flag = false
  and l.layout_id = t.layout_id
  and t.del_flag = false
  and a.asset_type = 'FILE'
  and (t.theme_id = a.root_parent_id or s.subject_id = a.root_parent_id)
  LIMIT 1000 OFFSET 0
  ;
  ```

## データ移行作業  
1. 対象環境のstorage用バケット名を確認し、移行コマンド生成シートのB1に入力する。  
2. [事前作業](#事前作業)で取得した登録済みアセット情報から移行コマンド生成シートを作成する。  
   1. Export to csvでダウンロードしたファイルをテキストエディタで開く。  
   2. CSVファイルの全行を選択してコピーする。  
   3. コマンド生成シートのA3列を選択し、貼り付けする。
      ![](./work/paste.png)
   4. Excelのデータタブの区切り位置メニューを押下し、元のデータ形式に「カンマやタブなどの区切り文字によってフィールドごとに区切られたデータ」を選択し、次へを押下する。 
      ![](./work/delimiter-1.png)
   5. 区切り文字に「カンマ」を選択し、次へを押下する。  
      ![](./work/delimiter-2.png)
   6. データのプレビューで全ての列を選択し、列のデータ形式に「文字列(T)」を選択し、完了を押下する。  
      ![](./work/delimiter-3.png)
   7. 貼り付けた行数分C3とD3をC列D列のアセット情報分コピーする。  
      ![](./work/command.png)
3. J4以降のコマンドをターミナルで実行する。  

## 事後作業  
1. コマンド生成シートのK4以降のコマンドをターミナルで実行する。  

## 変更履歴
- 2022/12/14 小島 新規作成
- 2022/12/20 小島 手順修正