## これは何？

vCenterからアラームの情報を取り出すツールです。
PowerCLIで取り出してCSVに保存、Excelマクロで整形という流れで、最終的な生成物はExcelファイルになります。



## 使い方

0. 作業端末にPowerCLIをインストールする
PowerShellを開いて下記コマンドを実行
```
Install-Module VMware.PowerCLI
```

1. Export-vCenterAlarmInfo.ps1 を読み込む
PowerCLIを開いて、ファイルの中身をコピペ

2. 下記コマンドを実行してCSV作成
```
Connect-VIServer <vCenterサーバーのIP or FQDN> -User administrator@vsphere.local -Password <パスワード>
Export-vCenterAlarm | Export-Csv -Encoding UTF8 -NoTypeInformation -Path <保存するCSVのフルパス.csv>
```

4. CSVを整形
* vCenerアラームCSV整形用マクロ.xlsm を開いて、画面上部の「コンテンツの有効化」をクリックしてマクロを有効化する
* 保存したCSVを開く（Excelでね）
* CSVを開いた画面が前面にある状態で、Alt + F8 を押して「きれいにするやつ」マクロを実行
* Excel形式で保存

