# do not remove the { } from the top and bottom of this page!!!
# translation by Jack Chen <chenn@cshl.edu>
{

 CHARSET =>   'Big5',

   #----------
   # MAIN PAGE
   #----------

   PAGE_TITLE => '基因組流覽器',

   SEARCH_INSTRUCTIONS => <<END,
根據序列名﹐ 基因名﹐遺傳位點%s, 或其他標記進行查詢. 允許使用通配符.
END

   NAVIGATION_INSTRUCTIONS => <<END,
點擊尺子使位點居中. 使用卷動/縮放按鈕改變放大?數和位置. 
END

   EDIT_INSTRUCTIONS => <<END,
在此編輯你的上載註釋數據. 你可用表格(tab) 鍵或空白分界,
但如果數據中有 tab  或空白﹐ 必須用引號.
END

   SHOWING_FROM_TO => '顯示 %s 起始于 %s, 位置從 %s 到 %s',

   INSTRUCTIONS      => '提示',

   HIDE              => '隱藏',

   SHOW              => '顯示',

   SHOW_INSTRUCTIONS => '顯示提示',

   HIDE_INSTRUCTIONS => '隱藏提示',

   SHOW_HEADER       => '顯示抬頭',

   HIDE_HEADER       => '隱藏抬頭',

   LANDMARK => '標誌或區域',

   BOOKMARK => '設置書籤',


    IMAGE_LINK => '圖形鏈接',

    SVG_LINK   => '高質量圖形',

    SVG_DESCRIPTION => <<END,
<p>
以下鏈接可生成SVG格式的圖形。  SVG格式比jpeg或png格式有多重優點.
</p>
<ul>
<li>能放大縮小﹐不影響清晰度。
<li>可利用一些軟件進行編輯。
<li>可轉換成EPS格式供發表
</ul>
<p>
需用SVG特別軟件流覽﹐ 如Adobe SVG 流覽器插件﹐ 或Adobe Illustrator。
</p>
<p>
Adobe's SVG 流覽器插件﹕ <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Macintosh">Macintosh</a>
| <a
href="http://www.adobe.com/support/downloads/product.jsp?product=46&platform=Windows">Windows</a>
<br />
Linux用戶可嘗試使用<a href="http://xml.apache.org/batik/">Batik SVG 流覽器</a>.
</p>
<p>
<a href="%s" target="_blank">在新視窗?觀察SVG圖像</a></p>
<p>
按control-click (Macintosh) 或鼠標右擊(Windows) 並選擇適當選項下載圖像
</p>   
END

   IMAGE_DESCRIPTION => <<END,
<p>
如需產生此圖像的鏈接﹐拷貝URL﹕
</p>
<pre>
&lt;IMAGE src="%s" /&gt;
</pre>
<p>
此圖像應是這樣﹕
</p>
<p>
<img src="%s" />
</p>

<p>
如選擇略覽(染色體或contig)﹐儘量縮小觀察區域。
</p>
END

   TIMEOUT  => <<'END',
超時。你可能選擇的區域過大。要避免超時﹐你可關掉一些數據道﹐選擇較小區域﹐或點擊"回執"鍵。
END
   GO       => '執行',

   FIND     => '尋找',

   SEARCH   => '查詢',

   DUMP     => '顯示',

   HIGHLIGHT   => '強調',

   ANNOTATE     => '註解',

   SCROLL   => '卷動/縮放',

   RESET    => '重置',

   FLIP     => '顛倒',

   DOWNLOAD_FILE    => '下載文件',

   DOWNLOAD_DATA    => '下載數據',

   DOWNLOAD         => '下載',

   DISPLAY_SETTINGS => '顯示設置',

   TRACKS   => '數據道',

   EXTERNAL_TRACKS => '外來數據道(斜體)',

   OVERVIEW_TRACKS => '<sup>*</sup>概覽數據道',

   REGION_TRACKS => '<sup>**</sup>?域?据道',

   EXAMPLES => '範例',

   REGION_SIZE => '?域大小(bp)',

   HELP     => '幫助',

   HELP_FORMAT => '幫助文件格式',

   CANCEL   => '取消',

   ABOUT    => '關於...',

   REDISPLAY   => '重新顯示',

   CONFIGURE   => '配置...', 

   CONFIGURE_TRACKS   => '配置?据道',

   EDIT       => '編輯文件...',

   DELETE     => '刪除',

   EDIT_TITLE => '輸入/編輯註釋數據',

   IMAGE_WIDTH => '圖像寬度',

   BETWEEN     => '之間',

   BENEATH     => '下面',

   LEFT        => '左面',

   RIGHT       => '右面',

   TRACK_NAMES => '數據道名稱表',

   ALPHABETIC  => '字母',

   VARYING     => '變化',

   SET_OPTIONS => '設定特征數據選項...',
  
   CLEAR_HIGHLIGHTING => '复原',

   UPDATE      => '更新圖像',

   DUMPS       => '轉存﹐ 查詢及其他選擇',

   DATA_SOURCE => '數據來源',

   UPLOAD_TRACKS=>'上載數據道',

   UPLOAD_TITLE=> '上載註釋',

   UPLOAD_FILE => '上載文件',

   KEY_POSITION => '註解位置',

   BROWSE      => '流覽',

   UPLOAD      => '上載',

   NEW         => '新',

   REMOTE_TITLE => '增加遠程註解',

   REMOTE_URL   => '輸入遠程註解網址',

   UPDATE_URLS  => '更新網址',

   PRESETS      => '--選擇當前網址--',

   FEATURES_TO_HIGHLIGHT => '需??的特征',

   REGIONS_TO_HIGHLIGHT => '需??的?域',

   FEATURES_TO_HIGHLIGHT_HINT => '暗示：用特征@?色????色，如\'NUT21@淡?\'\'',

   REGIONS_TO_HIGHLIGHT_HINT  => '暗示：用特征@?色????色，如\'Chr1:10000..20000@淡?\'\'',

    NO_TRACKS    => '*空白*',

   FILE_INFO    => '最近修改于 %s.  註釋標誌為: %s',

   FOOTER_1     => <<END,
注: 此頁利用 cookie 儲存相關信息. 數據不會混淆.
END

   FOOTER_2    => '通用基因組流覽器版本 %s',

   #----------------------
   # MULTIPLE MATCHES PAGE
   #----------------------

   HIT_COUNT      => '以下區域 %d滿足你的要求.',

   POSSIBLE_TRUNCATION  => '搜尋結果限於 %d 次。一些結果會能不完全',

   MATCHES_ON_REF => '符合于 %s',

   SEQUENCE        => '序列',

   SCORE           => '積分=%s',

   NOT_APPLICABLE => '無關',

   BP             => 'bp',

   #--------------
   # SETTINGS PAGE
   #--------------

   SETTINGS => '%s  的設置',

   UNDO     => '復原',

   REVERT   => '返回缺損值',

   REFRESH  => '更新屏幕',

   CANCEL_RETURN   => '取消改變並返回...',

   ACCEPT_RETURN   => '接受改變並返回...',

   OPTIONS_TITLE => '特征數據選項',

   SETTINGS_INSTRUCTIONS => <<END,
<i>顯示</i>負責打開和關閉路徑. <i>緊縮</i> 迫使路徑縮小以便註釋可以重迭. The <i>擴展</i> 和 <i>通過鏈接</i> 選項利用慢速和快速展開算法開啟碰撞控制. <i>擴展</i> 和 <i>標記</i> ﹐以及 <i>通過鏈接的擴展和標記l</i> 迫使註釋被標記上. 如果 選擇<i>自動</i> , 碰撞控制和標記選項 將會被自動選用. 如要改變路徑的順序﹐可使用 <i>改變路徑順序</i> 菜單. 如用限制註釋數量, 則改變 <i>極限</i> 的值.
END

   TRACK  => '數據道',

   TRACK_TYPE => '數據道類型',

   SHOW => '顯示',

   FORMAT => '格式',

   LIMIT  => '極限',

   ADJUST_ORDER => '調整順序',

   CHANGE_ORDER => '改變特征數據順序',

   AUTO => '自動',

   COMPACT => '緊縮',

   EXPAND => '擴展',

   EXPAND_LABEL => '擴展並標記',

   HYPEREXPAND => '通過鏈接擴展',

   HYPEREXPAND_LABEL =>'通過鏈接擴展並標記',

   NO_LIMIT    => '無邊界',

   OVERVIEW    => '概覽',

   ANALYSIS    => '分析',

   GENERAL     => '概?',

   DETAILS     => '細節',

   REGION      => '?域', 

   ALL_ON      => '全選',

   ALL_OFF     => '全關',

   #--------------
   # HELP PAGES
   #--------------

   CLOSE_WINDOW => '關閉窗口',

   TRACK_DESCRIPTIONS => '特征數據的描述及引用',

   BUILT_IN           => '這個服務器的內部特征數據',

   EXTERNAL           => '外部註釋特征數據',

   ACTIVATE           => '請激活這?征數據以便閱讀相關信息.',

   NO_EXTERNAL        => '沒有載入外部特徵.',

   NO_CITATION        => '無進一步相關信息.',

   #--------------
   # PLUGIN PAGES
   #--------------

 ABOUT_PLUGIN  => '關於 %s',

 BACK_TO_BROWSER => '返回流覽器',

 PLUGIN_SEARCH_1   => '%s (通過 %s 查詢)',

 PLUGIN_SEARCH_2   => '&lt;%s 查詢&gt;',

 CONFIGURE_PLUGIN   => '配置',

 BORING_PLUGIN => '這個插入軟件無額外配置.',

   #--------------
   # ERROR MESSAGES
   #--------------

 NOT_FOUND => '這?標誌 <i>%s</i> 無法識別. 請參閱幫助網頁.',

 TOO_BIG   => '詳細閱讀範圍局限於 %s 緘基.  點擊簡介並 選擇區域 %s bp 寬.',

 PURGED    => "找不到文件 %s.  可能已被刪除 ?.",

 NO_LWP    => "這個服務器不能獲取外部網址.",

 FETCH_FAILED  => "不能獲取 %s: %s.",

 TOO_MANY_LANDMARKS => '%d 標誌.  太多而列不出.',

 SMALL_INTERVAL    => '將區域縮小到 %s bp',


 NO_SOURCES        => '找不到可讀的數據。或許你沒有閱讀權限。',
};



