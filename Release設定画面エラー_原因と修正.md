# Delphi の Release 設定画面エラー：原因と修正記録

記録日：2026-09-11

## 症状と解決結果

`SYNC_Breath.dproj` を Delphi IDE で開いた際、プロジェクト設定画面で Release を選ぶとエラーが発生し、Debug では発生しなかった。

後述の2点を修正した後、ユーザーが「直った」と報告し、設定画面の問題が解消したことを確認した。エラーダイアログの正確な文言・例外名は記録していない。これは設定画面の問題であり、Release のコンパイルエラーとして報告されたものではない。

## 対象と比較元

- 修正対象：`D:\DelphiProg\SYNC_Breath\SYNC_Breath.dproj`
- 対応するソース：`D:\DelphiProg\SYNC_Breath\SYNC_Breath.dpr`（変更なし）
- 正常な設定の比較元：`D:\DelphiProg\AviUtl2Plugin\Syncroh2\Syncroh2_Extension2.dproj`
- 比較元のソース：`D:\DelphiProg\AviUtl2Plugin\Syncroh2\Syncroh2_Extension2.dpr`

当初提示された `D:\DelphiProg\AviUtl2Plugin\Syncroh2\Syncroh2\_Extension2.dproj` と `.dpr` は存在しなかったため、近隣を検索して上記ファイルを比較に用いた。

対象は Win64 の DLL プロジェクト。ローカルの Delphi ツール配置は `C:\Program Files (x86)\Embarcadero\Studio\37.0`、プロジェクトの `ProjectVersion` は `20.4`。

## 原因の判断と確度

最有力の原因候補は、Release の設定ブロックに独自に追加されていた `<BT_BuildType>Release</BT_BuildType>`。正常な比較元には、この Release の指定がなかった。

併せて、Debug／Release の Win64 設定が `Import` より後ろに別ブロックとして追記されていた。正常な比較元では、プラットフォーム別設定は `Cfg_1_Win64`／`Cfg_2_Win64` のブロックにまとめられ、`Import` より前に置かれていた。

**2点を同時に修正して解消したため、どちらか一方が単独で原因だったかは切り分けていない。** `BT_BuildType` の許容値一覧や IDE 内部の例外発生箇所も確認していない。そのため「Release という値が必ず無効」「Import 後の PropertyGroup が必ずエラーになる」と一般化してはいけない。

## 修正1：Release の BT_BuildType 指定を削除

修正前：

```xml
<PropertyGroup Condition="'$(Cfg_2)'!=''">
    <BT_BuildType>Release</BT_BuildType>
    <DCC_LocalDebugSymbols>false</DCC_LocalDebugSymbols>
    <DCC_Define>RELEASE;$(DCC_Define)</DCC_Define>
    <DCC_SymbolReferenceInfo>0</DCC_SymbolReferenceInfo>
    <DCC_DebugInformation>0</DCC_DebugInformation>
</PropertyGroup>
```

修正後：

```xml
<PropertyGroup Condition="'$(Cfg_2)'!=''">
    <DCC_LocalDebugSymbols>false</DCC_LocalDebugSymbols>
    <DCC_Define>RELEASE;$(DCC_Define)</DCC_Define>
    <DCC_SymbolReferenceInfo>0</DCC_SymbolReferenceInfo>
    <DCC_DebugInformation>0</DCC_DebugInformation>
</PropertyGroup>
```

`Release` というビルド構成や `RELEASE` 条件定義は維持した。Debug 側の `BT_BuildType=Debug` も維持している。`BT_BuildType` を構成名と同じ文字列に機械的に設定しないこと。

## 修正2：末尾の設定を既存の構成別ブロックへ統合

修正前は `Import` の後ろに、次の条件を持つブロックが追加されていた。

```xml
<PropertyGroup Condition="'$(Config)'=='Debug' And '$(Platform)'=='Win64'">
    <!-- Debug / Win64 の設定 -->
</PropertyGroup>
<PropertyGroup Condition="'$(Config)'=='Release' And '$(Platform)'=='Win64'">
    <!-- Release / Win64 の設定 -->
</PropertyGroup>
```

これらの設定値を、`Import` より前にある次の既存ブロックへ移動し、末尾の重複ブロックを削除した。

```xml
<PropertyGroup Condition="'$(Cfg_1_Win64)'!=''">
    <!-- Debug / Win64 の設定 -->
</PropertyGroup>
<PropertyGroup Condition="'$(Cfg_2_Win64)'!=''">
    <!-- Release / Win64 の設定 -->
</PropertyGroup>
```

移動した項目：

- `Manifest_File`
- `AppDPIAwarenessMode`
- `DCC_ExeOutput`
- `PreBuildEvent` と `PreBuildEventIgnoreExitCode`
- `PostBuildEvent` と `PostBuildEventIgnoreExitCode`
- `Debugger_HostApplication`（既存の同じ値と統合）

出力先、ビルドイベントのコマンド、ホストアプリのパスは変更していない。Release の DLL を `.auf2` にコピーして DLL／RSM を削除する既存処理も維持した。

## 検証結果

1. XML として読み込み可能であることを確認した。
2. `git diff --check` が成功した。
3. ローカルの Delphi Targets を使用した MSBuild の前処理が Debug／Win64 と Release／Win64 の両方で成功した。
4. 修正後、ユーザーが IDE 上の問題の解消を確認した。

MSBuild の確認は `/pp` によるインポート展開であり、コンパイルやプラグインの実行確認ではない。IDE の設定画面が正常になったという根拠はユーザーの確認による。

## 他のAIが同様の問題を修正するときの手順

1. まず `.dproj` の未コミット変更を確認し、既存のユーザー設定を保持する。
2. エラーが IDE の設定画面で起きるのか、ビルド時に起きるのかを区別する。
3. 同じ環境で正常に開ける `.dproj` と、構成条件・`BT_BuildType`・設定ブロックの配置を比較する。
4. この事例と同じ `BT_BuildType=Release` があれば、正常な比較元に合わせて削除する。Release 構成自体や `RELEASE` 定義は削除しない。
5. `Import` 後に追記された構成別設定があれば、対応する既存ブロックに値を保持して統合する。`Cfg_1` が必ず Debug とは限らないため、各プロジェクトの `BuildConfiguration` の `Key` を確認する。
6. XML、差分、MSBuild の読み込みを確認したうえで、IDE でプロジェクトを開き直し、Release の設定画面を確認する。
7. 原因を厳密に特定する必要があれば、変更を1点ずつ適用して再現を比較する。本件ではその切り分けは未実施。

プロジェクト全体を比較元で置き換えないこと。GUID、参照ユニット、出力先、拡張子などは各プロジェクト固有であり、本件では `.dpr` や Pascal の処理コードの変更は不要だった。
