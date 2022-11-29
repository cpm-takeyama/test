set time2=%time: =0%
cd C:\Program Files (x86)\apache-jmeter-5.4.3\apache-jmeter-5.4.3\bin
jmeter -n -t DAM_ZIPULテスト_レイアウト1111.jmx -e -o report_CcSuite_DAMzip解凍ULレイアウト_竹山ラッシュ記録_%date:~0,4%%date:~5,2%%date:~8,2%%time2:~0,2%%time2:~3,2%%time2:~6,2% -l CcSuite_DAMzip解凍ULレイアウト_竹山ラッシュ記録_%date:~0,4%%date:~5,2%%date:~8,2%%time2:~0,2%%time2:~3,2%%time2:~6,2%.jtl -Jthread=18 -Jrampup=60 -Jloop=30
