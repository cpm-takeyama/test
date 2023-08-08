/* 目的：案件別の結果を出したい */
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
        and (
            exists (
                    --テーマ分
                    select
                        *
                    from
                        brand b,
                        subject s,
                        layout l,
                        theme t
                    where
                        b.del_flag = false
                        and b.brand_id = s.brand_id
                        and s.del_flag = false
                        and s.subject_id = l.subject_id
                        and l.del_flag = false
                        and l.layout_id = t.layout_id
                        and t.del_flag = false
                        and t.theme_id = a.parent_id
                    )
                or
            exists (
                    --案件フォルダ分
                    select
                        *
                    from
                        brand b,
                        subject s
                    where
                        b.del_flag = false
                        and b.brand_id = s.brand_id
                        and s.del_flag = false
                        and s.subject_id = a.parent_id
                    )
            )
    UNION ALL
    --その他のファイルおよびディレクトリすべて
    select
        --すべてのディレクトリおよびファイルが、大元の案件フォルダもしくはテーマを親とする表になる
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
    brand_name,
    subject_id,
    subject_name,
    sum(dir_count) as dir_count,
    sum(file_count) as file_count,
    sum(used) as used
from
    --as data
    (
    --テーマ分
    select
        b.brand_name,
        s.subject_id,
        s.subject_name,
        sum(case when a.asset_type = 'DIRECTORY' then 1 else 0 end) as dir_count,
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
        and t.theme_id = a.root_parent_id --テーマ配下のディレクトリおよびファイル
    group by
        b.brand_name,
        s.subject_id,
        s.subject_name
    UNION ALL
    --案件フォルダ分
    select
        b.brand_name,
        s.subject_id,
        s.subject_name,
        sum(case when a.asset_type = 'DIRECTORY' then 1 else 0 end) as dir_count,
        sum(case when a.asset_type = 'FILE' then 1 else 0 end) as file_count,
        sum(a.data_size) as used
    from
        brand b,
        subject s,
        assets a
    where
        b.del_flag = false
        and b.brand_id = s.brand_id
        and s.del_flag = false
        and s.subject_id = a.root_parent_id --案件フォルダ配下のディレクトリおよびファイル
    group by
        b.brand_name,
        s.subject_id,
        s.subject_name
    ) as data
group by
    brand_name,
    subject_id,
    subject_name
order by
    brand_name ASC
;