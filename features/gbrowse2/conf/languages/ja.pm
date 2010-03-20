# do not remove the { } from the top and bottom of this page!!!
{

   # Translated by Toshiaki Katayama <k@bioruby.org>
   # Sat Jun 12 23:11:24 JST 2004

   CHARSET => 'euc-jp',

   #----------
   # MAIN PAGE
   #----------

   PAGE_TITLE => 'ゲノムブラウザー',

   SEARCH_INSTRUCTIONS => <<END,
配列の名前、遺伝子名、ゲノム上の位置、
その他のランドマークなどを使って検索します。
ワイルドカード文字として * を使うことができます。
END

   NAVIGATION_INSTRUCTIONS => <<END,
ルーラー上でクリックした位置が中心になります。
スクロールとズームボタンを使って拡大率と位置を変更します。
END

   EDIT_INSTRUCTIONS => <<END,
ここでアップロードしたアノテーションのデータを編集します。
フィールド間を区切るにはタブやスペースを使うことができますが、
フィールド自体が空白文字を含む場合には、
フィールドをシングルまたはダブルクォートで囲む必要があります。
END

   SHOWING_FROM_TO   => '%s の範囲を %s から表示、塩基番号 %s から %s',

   INSTRUCTIONS      => '説明',

   HIDE              => '隠す',

   SHOW              => '表示',

   SHOW_INSTRUCTIONS => '説明を表示',

   HIDE_INSTRUCTIONS => '説明を隠す',

   SHOW_HEADER       => 'バナーを表示',

   HIDE_HEADER       => 'バナーを隠す',

   LANDMARK	     => 'ランドマークまたは領域',

   BOOKMARK          => 'この表示をブックマーク',

   IMAGE_LINK        => 'この画像へのリンク',

   SVG_LINK          => '高品質SVG画像',

   SVG_DESCRIPTION => <<END,
<p>
→ <a href="%s" target="_blank">SVG 画像を新しいウィンドウで表示</a></p>
<p>
このリンクをクリックすると SVG (Scalable Vector Graphic) フォーマットの画像が
生成されます。SVG 画像には jpeg や png などのラスタ画像と比較して
次のような利点があります。
</p>
<ul>
<li>解像度を犠牲にせず、自由にサイズを変更できる
<li>一般的な画像処理ソフトを利用して、フィーチャーごとに自由な編集ができる
<li>論文投稿用など、必要に応じて EPS フォーマットに変換できる
</ul>
<p>
SVG 画像を見るためには、Adobe SVG browser プラグインなどの SVG 対応
ブラウザが、編集するためには、Adobe Illustrator などのソフトウェアが
必要になります。
</p>
<ul>
<li> Adobe の SVG browser プラグイン: <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Macintosh">Macintosh用</a>
| <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Windows">Windows用</a>
<li> Linux ユーザは <a href="http://xml.apache.org/batik/">Batik SVG Viewer</a>を試すとよいでしょう。
</ul>
<p>
SVG 画像を保存するには、上記のリンクを Macintosh の場合コントロールキーを
押しながらクリック、Windows の場合右クリックして、リンク先をディスクに保存する
オプションを選びます。
</p>
END

   IMAGE_DESCRIPTION => <<END,
<p>
この画像を HTML ページに埋め込むには、次の URL をコピー＆ペーストします:
</p>
<pre>
&lt;IMAGE src="%s" /&gt;
</pre>
<p>
画像はこのように表示されることになります:
</p>
<p>
<img src="%s" />
</p>

<p>
もし（染色体やコンティグなど）オーバービューしか表示されていない場合、
領域のサイズを縮めてみてください。
</p>
END

   TIMEOUT           => <<'END',
処理がタイムアウトしました。
選択した領域が一度に表示するには広すぎた可能性があります。
表示領域を狭めるか不要な項目を表示しないようにしてみてください。
タイムアウトが続く場合は赤色の「リセット」ボタンをクリックしてください。
END

   GO                => '実行',

   FIND              => '検索',

   SEARCH            => '検索',

   DUMP              => '出力',

   HIGHLIGHT         => '強調',

   ANNOTATE          => '解析',

   SCROLL            => 'スクロール/ズーム',

   RESET             => 'リセット',

   FLIP              => '反転',

   DOWNLOAD_FILE     => 'ファイルをダウンロード',

   DOWNLOAD_DATA     => 'データをダウンロード',

   DOWNLOAD          => 'ダウンロード',

   DISPLAY_SETTINGS  => '表示設定',

   TRACKS            => '表示項目',

   EXTERNAL_TRACKS   => '(外部の項目は斜体表示)',

   OVERVIEW_TRACKS   => '<sup>*</sup>オーバービューの項目',

   REGION_TRACKS     => '<sup>**</sup>領域の項目',

   EXAMPLES          => '例',

   REGION_SIZE       => '領域のサイズ (bp)',

   HELP              => 'ヘルプ',

   HELP_FORMAT       => 'ファイルフォーマットについてヘルプ',

   CANCEL            => '取り消し',

   ABOUT             => '解説...',

   REDISPLAY         => '再描画',

   CONFIGURE         => '設定...',

   CONFIGURE_TRACKS  => '項目の設定...',

   EDIT              => 'ファイルを編集...',

   DELETE            => 'ファイルを削除',

   EDIT_TITLE  	     => 'アノテーションデータの入力/編集',

   IMAGE_WIDTH 	     => '画像の横幅',

   BETWEEN     	     => '項目間',

   BENEATH     	     => '下端',

   LEFT              => '左端',

   RIGHT             => '右端',

   TRACK_NAMES 	     => '項目名リスト',

   ALPHABETIC  	     => '名前順',

   VARYING     	     => '種類別',

   SET_OPTIONS 	     => '項目毎の設定...',

   CLEAR_HIGHLIGHTING => '強調表示を解除',

   UPDATE      	     => '画像を更新',

   DUMPS       	     => '出力や解析などの操作',

   DATA_SOURCE 	     => 'データソース',

   UPLOAD_TRACKS     => 'アノテーションの追加',

   UPLOAD_TITLE	     => '独自アノテーションをアップロード',

   UPLOAD_FILE 	     => 'アップロードするファイル',

   KEY_POSITION      => '項目の表示位置',

   BROWSE            => '選択...',

   UPLOAD            => 'アップロード',

   NEW               => '新規...',

   REMOTE_TITLE      => '外部アノテーションを追加',

   REMOTE_URL        => '外部アノテーションのURL',

   UPDATE_URLS       => 'URLを更新',

   PRESETS           => '--リストから URL を選択--',

   FEATURES_TO_HIGHLIGHT      => 'フィーチャーを強調表示 (feature1@color1 feature2@color2 ...)',

   REGIONS_TO_HIGHLIGHT       => '領域を強調表示 (region1:start..end@color1 region2:start..end@color2 ...)',

   FEATURES_TO_HIGHLIGHT_HINT => 'ヒント： フィーチャー（遺伝子名等）を強調表示するには「フィーチャー@色」を \'NUT21@lightblue\' の書式で指定',

   REGIONS_TO_HIGHLIGHT_HINT  => 'ヒント： 領域を強調表示するには「領域@色」を \'Chr1:10000..20000@lightblue\' の書式で指定',

   NO_TRACKS         => '(なし)',

   FILE_INFO         => '最終更新日 %s / アノテーションされたランドマーク: %s',

   FOOTER_1          => <<END,
注意: このページは設定を保存するためにクッキーを使用しています。
クッキーの情報を他に流用することはありません。
END

   FOOTER_2          => 'Generic genome browser バージョン %s',

   #----------------------
   # MULTIPLE MATCHES PAGE
   #----------------------

   HIT_COUNT         => '以下の %d 領域がマッチしました。',

   POSSIBLE_TRUNCATION => '検索結果中 %d 件を表示 (全部表示されていない場合があります)',

   MATCHES_ON_REF    => '%s にマッチ',

   SEQUENCE          => '配列',

   SCORE             => 'スコア=%s',

   NOT_APPLICABLE    => 'n/a',

   BP                => 'bp',

   #--------------
   # SETTINGS PAGE
   #--------------

   SETTINGS          => '%s の設定',

   UNDO              => '変更の取り消し',

   REVERT            => 'デフォルト値に戻す',

   REFRESH           => '更新',

   CANCEL_RETURN     => '変更を取り消して戻る...',

   ACCEPT_RETURN     => '変更を適用して戻る...',

   OPTIONS_TITLE     => '項目のオプション',

   SETTINGS_INSTRUCTIONS => <<END,
<i>表示</i> チェックボックスで項目をオン・オフします。
<i>簡易</i> フォーマットは項目を縮めて表示するため
アノテーションがオーバーラップする可能性があります。
<i>拡張</i> と <i>特別</i> フォーマットはアノテーションの
レイアウトに遅いまたは速い重なり検出アルゴリズムを使います。
<i>拡張 &amp; ラベル</i> と <i>特別 &amp; ラベル</i>
フォーマットはアノテーションに必ずラベルをつけます。
<i>自動</i> を選んだ場合には、スペースがある限り、
重なり検出とラベル機能が自動的に有効になります。
項目の順番を変更するには <i>順番の変更</i> ポップアップメニューを
使ってその位置に表示したいアノテーションを指定します。
表示されるアノテーションの数を制限するには <i>リミット</i> メニューの
値を変更します。
END

   TRACK             => '項目',

   TRACK_TYPE        => '項目のタイプ',

   SHOW              => '表示',

   FORMAT            => 'フォーマット',

   LIMIT             => 'リミット',

   ADJUST_ORDER      => '順番の調整',

   CHANGE_ORDER      => '順番の変更',

   AUTO              => '自動',

   COMPACT           => '簡易',

   EXPAND            => '拡張',

   EXPAND_LABEL      => '拡張 & ラベル',

   HYPEREXPAND       => '特別',

   HYPEREXPAND_LABEL => '特別 & ラベル',

   NO_LIMIT          => '無制限',

   OVERVIEW          => 'オーバービュー',

   EXTERNAL          => '追加項目',

   ANALYSIS          => '解析項目',

   GENERAL           => '一般項目',

   DETAILS           => '詳細ビュー',

   REGION            => '領域',

   ALL_ON            => '全てオン',

   ALL_OFF           => '全てオフ',

   #--------------
   # HELP PAGES
   #--------------

   CLOSE_WINDOW      => 'このウィンドウを閉じる',

   TRACK_DESCRIPTIONS => '項目の解説と引用',

   BUILT_IN          => 'このサーバにある項目',

#  EXTERNAL          => '外部のアノテーション項目',

   ACTIVATE          => 'この項目の情報を見るにはこの項目を有効にしてください。',

   NO_EXTERNAL       => '外部のフィーチャーはロードされていません。',

   NO_CITATION       => '他の情報はありません。',

   #--------------
   # PLUGIN PAGES
   #--------------

   ABOUT_PLUGIN      => '%s について',

   BACK_TO_BROWSER   => 'ブラウザに戻る',

   PLUGIN_SEARCH_1   => '%s (%s による検索)',

   PLUGIN_SEARCH_2   => '&lt;%s 検索&gt;',

   CONFIGURE_PLUGIN  => '設定',

   BORING_PLUGIN     => 'このプラグインにはその他の設定項目はありません。',

   #--------------
   # ERROR MESSAGES
   #--------------

   NOT_FOUND         => '<i>%s</i> というランドマークは認識できませんでした。ヘルプページを参照してください。',

   TOO_BIG           => '詳細ビューは %s までです。オーバービューをクリックして %s の領域を選んでください。',

   PURGED            => '%s という名前のファイルは見あたりません。すでに消されてしまった可能性があります。',

   NO_LWP            => 'このサーバは外部の URL から情報を取れるように設定されていません。',

   FETCH_FAILED      => '%s を取得できませんでした: %s.',

   TOO_MANY_LANDMARKS => 'ランドマーク数 %d は多すぎるため表示を省略します。',

   SMALL_INTERVAL    => '小さな間隔を %s bp にリサイズしました。',

   NO_SOURCES        => '表示可能なデータソースがありません。データの閲覧が許可されていない可能性もあります。'

};
