# SYNC_Breath 作業ノート

このファイルは `D:\DelphiProg\test\Shake_PPP\note.md` から、SYNC_Breathの開発・保守にも必要な共通方針を抜き出し、現在の実装に合わせて整理した作業資料である。呼吸表現の具体的な仕様は、実装方針が決まり次第このファイルへ追記する。

## プロジェクト構成

- `SYNC_Breath.dpr` はDLLのexport境界と必要ユニットの列挙だけを担当する。
- `Source\Plugin\Filter\SYNC_Breath_FilterPlugin.pas` はフィルター登録、設定ボタン、映像処理の入口を担当する。
- `Source\Plugin\Filter\SYNC_Breath_SettingsForm.pas/.dfm` は専用設定画面と画像プレビューを担当する。
- `Source\Common\Render\SYNC_Breath_LastFrameCapture.pas` は `GetImageTexture2D` からフィルター処理前の入力画像を取得して最新フレームとして保持する。入力画像を取得できない場合だけ `GetFramebufferTexture2D` へフォールバックする。
- 複数ユニットで共用する処理とAviUtl2 SDK型定義は `Source\Lib` に置く。
- プロジェクトはフォルダ完結型とし、`Syncroh2`など別プロジェクトのソースを直接参照しない。
- 参照元から不要なユニットを一括で持ち込まず、実際に使う依存だけを置く。
- 現在の映像コールバックは画像を変形せず、設定プレビュー用にフィルター前の最新フレームだけを取得する。

## 現在の最小仕様

- AviUtl2上のグループ名は `SYNC`、フィルター名は `呼吸` とする。
- フィルターの `設定` ボタンから専用GUIをモーダル表示する。
- 専用GUIは最後に取得した入力画像を表示する。
- マウスホイールで25%刻みに拡大縮小し、範囲は25～400%とする。
- 左ドラッグで表示位置を移動する。
- ダブルクリックで全体表示と中央配置へ戻す。
- 画像共有はクリティカルセクションで保護し、映像処理とGUIが同時にバッファーを操作しないようにする。
- 画像入力はRGBA/BGRA 8bit、RGBA 16bit整数、RGBA 16bit浮動小数点へ対応する。

## 共通ビルドルール

- Delphi 37.0を使用し、対象プラットフォームはWin64だけとする。
- DebugとReleaseのビルド設定を保つ。
- コンパイル警告とエラーを確認し、原則として警告0、エラー0で完了とする。
- ビルド前に `C:\ProgramData\aviutl2\Plugin\SYNC_Breath` がなければ作成し、DLLを同フォルダーへ出力する。
- DebugはDLLを `SYNC_Breath.auf2` へコピーし、調査用のDLLとRSMも残す。
- ReleaseはDLLを `SYNC_Breath.auf2` へコピーした後、同じ出力先のDLLとRSMを削除する。
- AviUtl2起動中は `.auf2` がロックされる。配備に失敗した場合はAviUtl2を終了してから再ビルドし、アプリケーションを強制終了しない。

Debug Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\SYNC_Breath\SYNC_Breath.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

Release Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\SYNC_Breath\SYNC_Breath.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

配備先:

```text
C:\ProgramData\aviutl2\Plugin\SYNC_Breath\SYNC_Breath.auf2
```

## ビルド後の確認

- DLLが `InitializePlugin`、`UninitializePlugin`、`GetFilterPluginTable` をexportしていることを確認する。
- `InitializePlugin` が成功値を返すことを確認する。
- フィルターテーブルの名称が `呼吸`、グループが `SYNC`、説明が `呼吸フィルタープラグイン` であることを確認する。
- 設定項目に `設定` ボタンがあり、項目配列がnil終端されていることを確認する。
- AviUtl2を再起動し、プラグイン認識、設定画面表示、画像表示、ホイール拡大縮小、ドラッグ移動、全体表示を実機確認する。
- 対応形式を変更した場合は、8bitと16bitの変換経路を確認する。

## 実装・保守ルール

- フィルターコールバック境界からDelphi例外を外へ漏らさない。SDKから呼ばれる処理は例外を捕捉し、安全な戻り値を返す。
- 毎フレームの処理ではファイル再読込、不要なメモリ確保、GUI値の書き戻しを行わない。
- 毎フレーム必要なバッファーとGPUリソースは、サイズ・形式・デバイスが変わらない限り再利用する。
- GUIへ渡す画像は共有バッファーを直接参照させず、ロック中に専用配列へコピーする。
- コメントは処理の言い換えではなく、目的、責務、注意点、状態や値の意味を補うために書く。
- コードを見れば明らかな代入や単純な分岐には、説明だけを繰り返すコメントを付けない。
- DelphiのSDKレコードはC/C++側のABIと一致させ、フィールド追加時は順序、型、呼出規約、アラインメントを公式SDKまたは確認済みの定義と照合する。
- export関数とSDKコールバックの `cdecl` を維持する。
- AviUtl2へ渡す名称や説明は `PWideChar` として扱う。ソースファイルの文字コードによる文字化けを避ける必要がある場合はUnicodeコード値で記述する。
- VCLの `TBitmap.ScanLine` とAviUtl2/D3D11画像の行方向、RGBA/BGRAのチャンネル順を混同しない。
- 対応していないDXGI形式を暗黙に処理せず、取得失敗として状態表示へ理由を渡す。
- 責務が増えたら専用ユニットへ分け、グローバルな可変状態を避ける。
- `Source\Lib`の共通定義を変更する場合は、現在使用していない機能まで無条件に追加せず、必要なAPIだけを同期する。
- 原因調査用ログを追加する場合はDebugビルドだけを対象とし、Releaseビルドでは出力しない。

## Git管理ルール

- `.pas`、`.dpr`、`.dproj`、`.dfm`、`.res`、文書、配布・検証に必要なスクリプトと素材を同期対象とする。
- `Win32`、`Win64`、`.dcu`、`.rsm`、`.dll`、`.auf2`、IDEローカル設定、履歴・復旧データは同期しない。
- `.gitattributes`を追加する場合はPascal、プロジェクト、文書の改行をCRLFへ統一する。
- `.res`などのバイナリーファイルはbinaryとして扱う。
- 自動生成物や配備先のファイルをソース管理へ含めない。

## 作業ログ

- 2026-09-11: `Shake_PPP`を参考に、Win64 Debug/Releaseと空の映像処理を備えた最小フィルタープラグインを作成した。
- 2026-09-11: グループ名を `SYNC`、フィルター名を `呼吸` とし、必須exportとフィルターテーブルを確認した。
- 2026-09-11: `設定`ボタン、専用GUI、最新入力画像の保持、画像表示、ホイール拡大縮小、ドラッグ移動、ダブルクリックによる全体表示を追加した。
- 2026-09-11: 日本語リテラルの文字化けを修正し、使用するSDK定義とフィルターテーブル処理を `Source\Lib` に置いてフォルダ完結型へ変更した。
- 2026-09-11: 16bit入力画像が表示されない問題を修正し、RGBA/BGRA 8bit、RGBA 16bit整数、RGBA 16bit浮動小数点へ対応した。
