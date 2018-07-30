#! /usr/bin/env ruby

require 'nokogiri'
require 'mechanize'
require 'json'
require 'uri'
require 'webrick'

$base_url = URI.parse("http://noahgate.com/ucard")
$page_base_url = "http://noahgate.com/library?rank=0&type=all&page="
# $page_base_url = "http://noahgate.com/library?rank=0&type=all&card_name=%E3%83%8E%E3%82%A2&page="
$heroine_base_url = "http://noahgate.com/library/show?card_key="
$heroine_hitokoto_base_uri = "http://d3f1nvrmws0ea2.cloudfront.net/sound/voice/"
$dir_path = "./data/"
$global_dir = "global/"
$global_setting_heroine_mode = false # ヒロインページのみ保存して scenario ページを保存しないフラグ

pp "heroin_mode is #{$global_setting_heroine_mode}"

# グローバル変数
$global_noah_flag = false # ノアの共用シーン画像保存フラグ

# ここにブラウザのCookieから取得したSessionIDを入れる
# このIDがあると成りすまして他人がログインできるので絶対に公開しないこと
# また30日有効で最新ではないIDでも使用可能なのでセキュリティ的に問題がある
# それにも関わらずhttp通信を行うのは正気の沙汰ではない
# WARNING
$session = "enter the your session id."
# WARNING

$agent = Mechanize.new

$no_wait_proc = Proc.new {sleep 0}
$wait_proc = Proc.new {sleep 1.5}

def agent_get(uri)
    unless uri.kind_of?(URI::HTTP) then
        parsed_uri = URI.parse(WEBrick::HTTPUtils.escape(uri))
    else
        parsed_uri = uri
    end
    begin
    if parsed_uri.host == "noahgate.com" then
        # pp "wait_get:" + parsed_uri.to_s
        return wait_get(parsed_uri)
    else
        # pp "no_wait_get:" + parsed_uri.path
        return no_wait_get(parsed_uri)
    end
    rescue Mechanize::ResponseCodeError => exception
        if exception.response_code == '403'
            # getのメッセージが残るので改行する
            # p ""
            p uri.to_s + " has 403 forbiddin."
            # STDERR.puts exception.backtrace.join("\n")
            return nil, false
        elsif exception.response_code == '502'
            p uri.to_s + " has 502 Bad Gateway.retry..."
            return agent_get(uri), true
        end
        pp exception
        raise # Some other error, re-raise
    rescue => exception
        pp exception
        return agent_get(uri), true # 謎エラーはリトライ
    end
end

def print_get(uri)
    print_str = "get #{uri}"
    # print print_str
    page = $agent.get(uri)
    # print "\r#{' ' * print_str.size}\r"
    return page
end

def no_wait_get(uri)
    $agent.history_added = $no_wait_proc
    return print_get(uri)
end

def wait_get(uri)
    $agent.history_added = $wait_proc
    return print_get(uri)
end


$agent.cookie_jar << Mechanize::Cookie.new('session', $base_url.host, {:value => $session, :domain => $base_url.host, :path=>"/"})
$agent.request_headers = {
    'Accept-Encoding' => 'gzip, deflate, br',
    'Accept-Language' => 'ja,en-US;q=0.9,en;q=0.8',
    'Upgrade-Insecure-Requests' => '1',
    'User-Agent' => 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36',
    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
    'Cache-Control' => 'max-age=0',
    'Referer' => 'http://noahgate.com/ucard',
    'Proxy-Connection' => 'on'
}

# pp $agent

# キャッシュ使用データ取得用メソッド
# Mechanize::Page オブジェクトを返す
def get_uri_html(uri)
    return agent_get(URI.parse(WEBrick::HTTPUtils.escape(uri)))
end

# キャッシュ使用データ取得用メソッド
# Mechanize::Page::XXXXX オブジェクトを返す
def get_uri_data(uri)
            return agent_get(uri), true
end

# uriからローカル保存用ファイル名に翻訳
# 引数にはURIオブジェクト
def translate_uri_to_local_file(uri, index=nil)
    file_name = uri.path.rpartition("/").last
    unless uri.query.nil? then
        file_name = file_name + "_" + uri.query + "." + get_ext_from_uri(uri.path)
    end
    return file_name
end

# URI → htmlの変換を保存する
# ./data/以下のpathを保持する
# $page_base_url + index の場合は特殊
$global_html_mapping = {}
$global_html_mapping_reverse = {}
def get_html_file_path_from_uri(uri)
    #pp "get_html_file_path_from_uri: " + uri.to_s
    if uri.to_s.start_with?($page_base_url) then
        return "./library_page_" + uri.to_s.rpartition("=").last + ".html"
    end
    return $global_html_mapping[uri.to_s]
end

def add_html_mapping(uri, path)
    $global_html_mapping[uri.to_s] = path.to_s

    $global_html_mapping_reverse[path.to_s] = uri.to_s
end
add_html_mapping("http://noahgate.com/library", "./library_page_1.html")

# html出力用メソッド
# 保存して相対ファイルパスを返す
# 常に上書き
def output_file(page, dir_file_name)
    relative_path = $dir_path + dir_file_name
    File.write(relative_path, page.root.to_html)
    add_html_mapping(page.uri, "./" + dir_file_name)
    return relative_path
end

# 拡張子の抽出
def get_ext_from_uri(uri)
    return uri.to_s.rpartition(".").last
end

# パス > ファイル名の抽出
def get_file_name_from_uri(path)
    return path.to_s.rpartition("/").last
end

def get_body_file_name_from_uri(path)
    get_file_name_from_uri(path).rpartition(".").first
end


# URI → pathの変換を保存する
$global_uri_mapping = {}
$global_uri_mapping_reverse = {}
# その他データ取得＆保存メソッド
# 保存フォルダ直下にキャッシュを利用して書き出す
# 常に上書きしない
# 返り値は /global/ファイル名
def output_global_data(uri)
    if $global_uri_mapping.key?(uri) then
        file_name = $global_uri_mapping[uri]
    else
        uri_obj = URI.parse(uri)
        file_name = translate_uri_to_local_file(uri_obj)
        unless $global_uri_mapping_reverse[file_name].nil? then
            file_body_name = get_body_file_name_from_uri(file_name)
            file_ext_name = get_ext_from_uri(file_name)
            now_file_name = file_name
            index = 2
            while !$global_uri_mapping_reverse[now_file_name].nil?
                now_file_name = file_body_name + "_" + index.to_s + "." + file_ext_name
                pp now_file_name
                index = index + 1
            end
            pp "info: file_name:'" + file_name + "' is conflict!! rename file to now_file_name:'" + now_file_name + "'"
            pp "info: '" + uri.to_s + "' is uri."
            pp "info: '" + $global_uri_mapping_reverse[file_name] + "' is $global_uri_mapping_reverse[file_name]."
            file_name = now_file_name
        end
        file_path = $dir_path + $global_dir + file_name
        unless File.exist?(file_path) then
            data, success = get_uri_data(uri)
            # 取得出来たら保存
            if success then
                data.save!(file_path)
            else
                p "could not get " + file_name + " from " + uri.to_s
            end
        end
        $global_uri_mapping[uri] = file_name

        $global_uri_mapping_reverse[file_name] = uri
    end
    return $global_dir + file_name
end

# 共通script削除処理
def delete_common_script(page)
    # script の削除 search しながら消すと位置がずれるのでやらない
    page_scripts = page.search("script")
    page_scripts[0].remove # newrelic関連
    page_scripts[1].remove # newrelic関連
    page.search("head script").last.remove # デバッグメッセージ非表示
end

# 共通img読み込み先変更処理
def common_image_link_rewrite(page)
    page_images = page.search('//img[starts-with(@src,"http://")]')
    page_images.each do |page_image|
        # pp page_image["src"]
        page_image["src"] = "./" + output_global_data(page_image["src"])
    end
end

# 共通css読み込み先変更処理
def common_css_link_rewrite(page, scenario = "")
    page_csss = page.search('//link[@type="text/css"]')
    # pp page_csss
    # ファイルの保存
    page_csss.each do |page_css|
        page_css["href"] = scenario + "./" + output_global_data(page_css["href"])
    end
end

# 共通js読み込み先変更処理
def common_js_link_rewrite(page, scenario = "")
    page_jss = page.search('//script[@type="text/javascript"][starts-with(@src, "http://")]')
    page_jss.each do |page_js|
        page_js["src"] = scenario + "./" + output_global_data(page_js["src"])
    end
end

# card 画面用 base_path 書き換え
def card_rewrite_js_base_path(page, heroine_directory_name)
    base_path_scripts = page.search('//script[@type="text/javascript"][contains(text(), "base_path")]')
    base_path_scripts.each do |base_path_script|
        # pp "before base_path:"
        # pp base_path_script
        rewrite_base_path = "'./" + heroine_directory_name + "/'"
        rewrite_base_path_script = base_path_script.child.text.gsub!(/[\"\'](http:\/\/[^\"\']+\/?)[\"\']/, rewrite_base_path)
        update_content(base_path_script, rewrite_base_path_script)
        # pp "after base_path:"
        # pp base_path_script
    end
end

# story 画面用 base_path 書き換え
def story_rewrite_js_base_path(page)
    base_path_script = page.at('//script[@type="text/javascript"][contains(text(), "base_path")]')
    # pp "before base_path:"
    # pp base_path_script
    # "bg"    : "http://d3f1nvrmws0ea2.cloudfront.net/img/novel/bg/",
    # pp base_path_script.content.match(/(\"bg\"[^\n]*\:[^\n]*")http\:\/\/[^\n]+(\")/)
    update_content(base_path_script, base_path_script.content.gsub!(/(\"bg\"[^\n]*\:[^\n]*")http\:\/\/[^\n]+(\")/, '"bg"    : "../' + $global_dir + '"'))
    # "emotion" : "http://d3f1nvrmws0ea2.cloudfront.net/img/novel/emotion/",
    update_content(base_path_script, base_path_script.content.gsub!(/(\"emotion\"[^\n]}*\:[^\n]*")http\:\/\/[^\n]+(\")/, '"emotion" : "../' + $global_dir + '"'))
    # "ui"    : "http://d3f1nvrmws0ea2.cloudfront.net/img/ui/novel/",
    update_content(base_path_script, base_path_script.content.gsub!(/(\"ui\"[^\n]*\:[^\n]*")http\:\/\/[^\n]+(\")/, '"ui"    : "../' + $global_dir + '"'))
    # "sound" : "http://d3f1nvrmws0ea2.cloudfront.net/sound/scenario_data/8202d1c43093bd88a895ea4c961cf7f3/",
    update_content(base_path_script, base_path_script.content.gsub!(/(\"sound\"[^\n]*\:[^\n]*")http\:\/\/[^\n]+(\")/, '"sound" : "./"'))
    # "chara" : "http://d3f1nvrmws0ea2.cloudfront.net/img/scenario_data/8202d1c43093bd88a895ea4c961cf7f3/",
    update_content(base_path_script, base_path_script.content.gsub!(/(\"chara\"[^\n]*\:[^\n]*")http\:\/\/[^\n]+(\")/, '"chara" : "./"'))
    # "movie" : "http://d3f1nvrmws0ea2.cloudfront.net/img/scenario_data/8202d1c43093bd88a895ea4c961cf7f3/",
    update_content(base_path_script, base_path_script.content.gsub!(/(\"movie\"[^\n]*\:[^\n]*")http\:\/\/[^\n]+(\")/, '"movie" : "./"'))

    # pp "after base_path:"
    # pp base_path_script
end

# 共通a href読み込み先変更処理
def common_a_link_rewrite(page)
    # pp "link rewrite page:" + page.uri.to_s
    page_links = page.search('//a[starts-with(@href, "http://")]')
    page_links.each do |page_link|
        # pp "page_link:" + page_link.to_s
        rewrite_to = get_html_file_path_from_uri(page_link["href"])
        if rewrite_to.nil? then
            # pp page_link
            pp page_link["href"] + " has not registered $global_html_mapping."
            pp "now page :" + page.uri.to_s
        end
        page_link["href"] = rewrite_to
    end
end

# css書き換え & 画像保存
def rewrite_css_file
    # .css 書き換え
    Dir.glob("**/*.css") do |css|
        buffer = ""
        File.open(css, "r") do |file|
            buffer = file.read
            matched_import = buffer.scan(/@import url\(([^.\/]{2}[^\)]*)\)/)
            matched_import.each do |import|
                before = import[0] # 書き換え元
                unless before.nil? then
                    path = output_global_data("http://noahgate.com/static/css/" + before)
                    file_name = get_file_name_from_uri(path)
                    after = "./" + file_name
                    buffer.gsub!("(" + before + ")", "(" + after + ")") # 置換
                end
            end

            matched_http = buffer.scan(/\((http\:\/\/[^\)]+)\)/)
            matched_http.each do |http|
                # pp http
                before = http[0] # 書き換え元
                unless before.nil? then
                    after = "./" + get_file_name_from_uri(output_global_data(before))
                    buffer.gsub!("(" + before + ")", "(" + after + ")") # 置換
                end
            end
        end
        # 書き換え
        File.open(css, "w") do |file|
            file.write buffer
        end
    end
end

# content書き換え
# 空白の場合正しくないことが多いのでロジック集約
def update_content(old, new_content)
    if new_content.nil? || new_content.empty? then
        pp "update_content by empty."
        STDERR.puts caller
        pp old
    end
    old.content = new_content
end

# ヒロインの情報
class Heroine
    # @@rare_to_max_plus = {:common => 999, :unCommon => 300, :rare => 50, :sRare => 30, :ssRare => 20, :animationRare => 10, :legendRare => 5}
    @@max_plus_to_rare = {"+999" => "C", "+300" => "UC", "+50" => "R", "+30" => "SR", "+20" => "SSR", "+10" => "AR", "+5" => "LR"}
    # 成長限界 → レア度 変換
    def self.max_plus_to_rare(max_plus)
        return @@max_plus_to_rare[max_plus]
    end
    attr_reader(:name, :rare, :card_key, :story_key, :heroine_directory_name, :heroine_directory_path)
    def initialize(name:, rare:, card_key:, story_key:)
        @uri_to_file = {}
        @name = name
        @rare = rare
        @card_key = card_key
        @story_key = story_key
        @heroine_directory_name = [@card_key, @name, @rare].join("_")
        @heroine_directory_path = $dir_path + @heroine_directory_name + "/"
    end


    def transfer_heroine_to_path(type:, index: nil, ext:)
        keywords = [type]
        unless index.nil?
            keywords.push(index)
        end
        return keywords.join("_") + "." + ext
    end

    # キャッシュをヒロインごとに保持する
    # ディスクチェックしてデータが存在したらダウンロードしない
    # filenameを返す
    def output_keyword_data(uri:, keyword:, index: nil)
        if @uri_to_file.key?(uri) then
            file_name = @uri_to_file[uri]
        else
            file_name = transfer_heroine_to_path(
                type: keyword, index: index, ext: get_ext_from_uri(uri))
            file_path = @heroine_directory_path + file_name
            unless File.exist?(file_path) then
                image, success = get_uri_data(uri)
                # 取得出来たら保存
                if success then
                    image.save!(file_path)
                else
                    p "could not get " + @heroine_directory_path + file_name + " from " + uri.to_s
                end
            end
            @uri_to_file[uri] = file_name
        end
        return file_name
    end

    # ヒロインのサムネイル取得～出力
    # 出力Pathを返す
    def output_thunbnail_image(img_uri)
        # pp "thumbnail:" + img_uri.to_s
        return output_keyword_data(uri: img_uri, keyword: "thumbnail")
    end

    # ヒロインの全身イラスト取得～出力
    # ヒロインディレクトリ以下の出力Pathを返す
    def output_standing_image(img_uri, index)
        return output_keyword_data(uri: img_uri, keyword: "standing", index: index)
    end

    # ヒロインのカードイラスト取得～出力
    # ロインディレクトリ以下の出力Pathを返す
    def output_card_image(img_uri, index)
        return output_keyword_data(uri: img_uri, keyword: "card", index: index)
    end

    # ヒロインのストーリーページ出力
    def output_story_page(index)
        story_page = get_uri_html("http://noahgate.com/story/play?story_key=#{@story_key}_#{index.to_s.rjust(2,"0")}&card_key=#{@card_key}")

        unless story_page.search("div.message_box_body").empty? then
            return nil, false
        end

        # storyページ改変

        # pp story_page.search("script")
        story_page.search("script")[0].remove

        base_setting_js_element = story_page.search("script")[5]
        # pp base_setting_js_element
        base_setting_js = base_setting_js_element.children[0].text.match(/var setting = (\{.+?\});/m)[1]
        base_setting = javascript_to_json(base_setting_js)

        scenario_setting_js_element = story_page.search("script")[4]
        scenario_setting_js = scenario_setting_js_element.children[0].text.match(/var scenarioSetting = (\{.+?\});/m)[1]
        scenario_setting = javascript_to_json(scenario_setting_js)

        # pp scenario_setting["chara"]

        base_bg_path = base_setting["base_path"]["bg"]
        base_emotion_path = base_setting["base_path"]["emotion"]
        base_ui_path = base_setting["base_path"]["ui"]
        base_image_path = base_setting["base_path"]["chara"]
        # pp base_image_path
        base_sound_path = base_setting["base_path"]["sound"]
        # pp base_sound_path
        base_movie_path = base_setting["base_path"]["movie"]
        # pp base_sound_path
        
        # ui画像保存
        base_setting["ui_images"].each do |ui_image|
            # pp 
            output_global_data(base_ui_path + ui_image)
        end

        # 画像保存
        # chara["id"] が一意で無い場合がある
        # name と chara["id"] が一致しない場合がある
        # 上記の場合において、 name で表示されているので name を真とする
        chara_name_to_src_hash = {}
        scenario_setting["chara"].each do |name, chara|
            unless chara["src"].nil? || chara["src"].empty? then
                if chara["src"] == "851edcbc47d806a3a55f19ee75593608.png" # このファイルの場合ノア固定
                    # globalに保存
                    unless $global_noah_flag then
                         output_global_data(base_image_path + chara["src"])
                         $global_noah_flag = true
                    end
                    image_file_name = "../global/851edcbc47d806a3a55f19ee75593608.png"
                else
                    if chara_name_to_src_hash.has_key?(name) then
                        pp "name conflict! :" +  @heroine_directory_path + "scenario_image_" + index.to_s + "_" + + name.to_s
                    end
                    image_file_name = output_keyword_data(uri: base_image_path + chara["src"], keyword: "scenario_image_" + index.to_s , index: name)
                end

                # name と chara["id"] (の末尾、または先頭)が一致しない場合は warning 多分ゲーム側のバグ
                if (!(name.include?("_") || !chara["id"].include?("_")) && name == chara["id"] ) || name.rpartition("_").last != chara["id"].rpartition("_").last || name.partition("_").first != chara["id"].partition("_").first then
                    pp "warn : #{@heroine_directory_path}#{image_file_name} : name and chara[\"id\"] not matched. name : '#{name}', chara[\"id\"] : #{chara["id"]}"
                end

                # 同じファイル名があった場合は warning 多分ゲーム側のバグ
                if chara_name_to_src_hash.has_value?(chara["src"])
                    pp "warn : #{@heroine_directory_path}#{image_file_name} : dupulicate chara[\"src\"] : #{chara["src"]} ."
                end

                # シナリオの画像書き換え
                # 同じファイル名があった場合に置換が空振りするのでチェック
                unless chara_name_to_src_hash.has_value?(chara["src"]) then
                    # pp "chara image transfer :" + chara["src"] + " to " + image_file_name + "."
                    update_content(scenario_setting_js_element, scenario_setting_js_element.content.gsub!(chara["src"], image_file_name))
            end
                chara_name_to_src_hash[name] = chara["src"]
        end
        end

        # シナリオデータ保存
        scenario_setting["scenario"].each do |cmd|
            if cmd["cmd"] == "playVoice" && !cmd["value"].nil? && !cmd["value"].empty? then
                voice_index = cmd["value"].rpartition("_").last.to_i
                output_keyword_data(uri: base_sound_path + "aac/" + cmd["value"] + ".aac", keyword: "aac/" + cmd["value"])
                # voice_file_name_body = voice_file_name_prefix + voice_index.to_s
                # pp "before:" + cmd["value"].to_s
                # pp scenario_setting_js_element.content.gsub(/(cmd[^\n]+playVoice[^\n]+value[^\n]+\")#{cmd["value"]}(\")/, "#{$1}#{voice_file_name_body}#{$2}")
                # シナリオのボイスは書き換えない
                # scenario_setting_js_element.content = scenario_setting_js_element.content.gsub!(/(cmd[^\n]+playVoice[^\n]+value[^\n]+\")#{cmd["value"]}(\")/, "#{$1}#{voice_file_name_body}#{$2}")
            elsif cmd["cmd"] == "showBG" && !cmd["value"].nil? && !cmd["value"].empty? then
                #pp cmd
                # showBG
                #pp base_bg_path + cmd["value"]
                output_global_data(base_bg_path + cmd["value"])
            elsif cmd["cmd"] == "showEmotion" && !cmd["value"].nil? && !cmd["value"].empty? then
                output_global_data(base_emotion_path + cmd["value"] + ".png") # pngはハードコーディングされている
            end
        end

        # movie保存
        scenario_setting_movie = scenario_setting["movie"]
        unless scenario_setting_movie.nil? then
            scenario_setting_movie.each_with_index  do |(name,movie),index_movie|
                unless movie.nil? or movie.empty? then
                    # pp name, movie
                    movie_file_name = output_keyword_data(uri: base_movie_path + movie, keyword: "scenario_movie_" + index.to_s, index: index_movie + 1)
                    # シナリオの movie 書き換え
                    update_content(scenario_setting_js_element, scenario_setting_js_element.content.gsub!(movie, movie_file_name))
                end
            end
        end

        # html 書き換え
        delete_common_script(story_page)
        # htmlの編集グローバルファイルで書き換え
        # 画像
        common_image_link_rewrite(story_page)
        # css
        common_css_link_rewrite(story_page, ".")
        # js
        common_js_link_rewrite(story_page, ".")

        # next_url 書き換え
        # "../" + now_heroine.heroine_directory_name + ".html"
        # "nextUrl" :"/story/show?card_key=40011"
        base_setting_js_element.content.match(/(\"nextUrl\"[^\n\"]+\")\/[^\n\"]+(\")/) # 先にmatchしておかないと正しく置換されない 謎
        update_content(base_setting_js_element, base_setting_js_element.content.gsub!(/(\"nextUrl\"[^\n\"]+\")\/[^\n\"]+(\")/, "#{$1}../#{heroine_directory_name}.html#{$2}"))
        # pp base_setting_js_element
        # nickname 書き換え
        base_setting_js_element.content.match(/(\"nickname\"[^\n\"]+\")[^\n\"]+(\")/) # 先にmatchしておかないと正しく置換されない 謎
        update_content(base_setting_js_element, base_setting_js_element.content.gsub!(/(\"nickname\"[^\n\"]+\")[^\n\"]+(\")/, "#{$1}#{$2}"))

        story_page.search('//div[@id="no_support"]').remove
        story_page.search('//div[@id="popup_menu"]').remove
        story_page.search('//div[@class="global_menu"]').remove
        story_page.search('//script').last.remove

        # base_path 書き換え
        story_rewrite_js_base_path(story_page)


        return output_file(story_page, @heroine_directory_name + "/scenario_" + index.to_s + ".html") ,true
    end

end

# javascriptをそれっぽく整形してJSON化する
# 行コメ削除
def javascript_to_json(javascript_string)
    return JSON.parse(
        javascript_string.gsub(/\/\/[^"]*$/,"").gsub(/'/,"\"").gsub(/,\s*\]/m, "]").gsub(/,\s*\}/m, "}").gsub(/\t/, " ")
        .gsub(/\"vector\"\:\(([\d,]+)\)/){"\"vector\":[#{$1}]"})
end


if __FILE__ == $0

    libray_page_number = 1 # TODO default 1
    while true
    pp "now libray_page_number:" + libray_page_number.to_s + " scraping."
        # アルバム一覧ページ取得
        libray_page = get_uri_html($page_base_url + libray_page_number.to_s)

        elements = libray_page.search("table.libraryTable a")
        if elements.empty?
            pp "this libray_page number:" + libray_page_number.to_s + " is empty"
            # pp libray_page
            break
        end

        elements.each do |heroine|
            heroine_url = heroine.attr("href")

            if heroine_url =~ /card_key=(\d+)$/
                heroine_card_key = $1
            end

            # ヒロインのlibraryページ取得
            heroine_page = get_uri_html($heroine_base_url + heroine_card_key)

            # 名前取得
            heroine_name = heroine_page.search("h1 > div.sub_title").children[0].text.strip.gsub(/[[:space:]]$/,"")
            
            # レア度取得
            heroine_rare = Heroine.max_plus_to_rare(
                heroine_page.search(
                    '//*[@id="top"]/div/div/table//tr[1]/td[2]/text()').text.strip)

            # story_key取得
            story_link = heroine_page.at("div.grid__col_md_5 > a")
            unless story_link.nil? then
                story_link_uri = URI.parse(story_link["href"])
                story_key_query = Hash[URI::decode_www_form(story_link_uri.query)]["story_key"]
                unless story_key_query.nil? then
                    story_key = story_key_query.split("_").first
                end
            end

            # ヒロインインスタンス生成
            now_heroine = Heroine.new(name: heroine_name, rare: heroine_rare, card_key: heroine_card_key, story_key: story_key)

            # thumbnail画像取得
            heroine_thumbnail_img = heroine.search("img").first
            heroine_thumbnail_uri = heroine_thumbnail_img["src"]
            heroine_thumbnail_path = now_heroine.heroine_directory_name + "/" + now_heroine.output_thunbnail_image(heroine_thumbnail_uri)

            #ページ書き換え
            heroine_thumbnail_img["src"] = heroine_thumbnail_path

            # ヒロイン全身イラスト
            heroine_page.search("[id^=leanModalZoom] > div > img").each_with_index do |standing_img, index|
                standing_img_uri = standing_img["src"]
                standing_img_path = now_heroine.heroine_directory_name + "/" + now_heroine.output_standing_image(standing_img_uri, index + 1)
                #ページ書き換え
                standing_img["src"] = standing_img_path
            end

            # 各立ち絵保存
            heroine_page.search("#imgCarousel > li > img").each_with_index do |card_img, index|
                card_img_uri = card_img["src"]
                card_img_path = now_heroine.heroine_directory_name + "/" + now_heroine.output_card_image(card_img_uri, index + 1)
                #ページ書き換え
                card_img["src"] = card_img_path
            end

            # 一言ボイス保存
            voice_buttons = heroine_page.search("a.btnVoice")
            voice_button = voice_buttons.last
            unless voice_button.nil? then
                # ラスト一文字だけ変える
                # たまにボイスのクエリーが違うので注意
                voice_button_query = voice_button["data-key"]
                voice_button_query_number = voice_button_query[-1]
                unless voice_button_query_number == "1" || voice_button_query_number == "2" then
                    p now_heroine.card_key + "_" + now_heroine.name + "_" + now_heroine.rare + ", voice_button_query: " + voice_button_query + " is unique."
                end
                voice_button_query_left = voice_button_query.chop
                now_heroine.output_keyword_data(uri: $heroine_hitokoto_base_uri + voice_button_query_left + "1" + ".aac", keyword: "card", index: 1)
                now_heroine.output_keyword_data(uri: $heroine_hitokoto_base_uri + voice_button_query_left + "2" + ".aac", keyword: "card", index: 2)
            end

            # voice_button 書き換え
            voice_buttons.each_with_index do |each_button, index|
                use_index = index + 1
                if use_index > 2 then
                    use_index = 2
                end
                each_button["data-key"] = "card_" + use_index.to_s
            end

            # storyページの保存
            story_links = heroine_page.search("div.grid__col_md_5 > a")
            story_links.each_with_index do |link, n|
                index = n + 1
                
                # 出力
                unless $global_setting_heroine_mode then
                    output_story_path, success = now_heroine.output_story_page(index)
                    unless success then
                    p now_heroine.card_key + "_" + now_heroine.name + "_" + now_heroine.rare + ", scene: " + index.to_s + " has not found."
                    end
                end
                # URL書き換え
                link["href"] = "./#{now_heroine.heroine_directory_name}/scenario_#{index.to_s}.html"

                # break # テスト用 TODO delete
            end

            # htmlの編集 > 全てのHTMLに適応？
            # 不要な要素
            heroine_page.search('//div[@id="no_support"]').remove
            heroine_page.search('//div[@id="popup_menu"]').remove
            heroine_page.search('//div[@class="side__banner_menu"]').remove
            heroine_page.search('//div[@class="side__menu"]').remove
            heroine_page.search('//div[@class="global_menu"]').remove
            btn_primary = heroine_page.search('//a[@class="btn_primary medium"]')
            # 武具ページにはこの要素が無いらしい
            unless btn_primary.nil? then
                btn_primary.remove
            else
                # 情報を出す → 不要
                # pp "info: " + now_heroine.heroine_directory_name + " card page btn_primary has not found."
            end


            # リンクの書き換えの前に同名ヒロインブロックを削除する
            # h4がある場合 btn_arrow_back までの a, div, br 要素を削除
            heroine_page.search('//div[@class="flex_panel type4"][last()]/following-sibling::node()[following-sibling::a[@class="btn_arrow_back "]]').remove
            # pp heroine_page.search('//div[@class="flex_panel type4"][last()]')
            # pp heroine_page.search('a[@class="btn_arrow_back "]')
            # pp heroine_page.search('//div[@class="flex_panel type4"][last()]/following-sibling::node()[following-sibling::a[@class="btn_arrow_back "]]')


            delete_common_script(heroine_page)

            # 個別
            heroine_page.search("//script").last.remove # menu関係操作用
            heroine_page.search('////*[@id="top"]/div[@class="h_block"]/div[div[span[text()="洗脳度:"]]]').remove
            
            # htmlの編集グローバルファイルで書き換え
            # 画像
            common_image_link_rewrite(heroine_page)

            # css
            common_css_link_rewrite(heroine_page)

            # js
            common_js_link_rewrite(heroine_page)
            # base_path書き換え
            card_rewrite_js_base_path(heroine_page, now_heroine.heroine_directory_name)

            # storyへの遷移を自己リンクへ変更する
            add_html_mapping("http://noahgate.com/story/show?card_key=" + now_heroine.card_key, "./" + now_heroine.heroine_directory_name + ".html")



            # linkの書き換え
            common_a_link_rewrite(heroine_page)

            # ヒロインページの保存
            local_heroine_page_path = output_file(heroine_page, now_heroine.heroine_directory_name + ".html")

            # break # テスト用 1ヒロインで止める TODO delete
        end

        # htmlの編集
        # 不要な要素
        libray_page.search('//div[@id="popup_menu"]').remove
        libray_page.search('//header').remove
        libray_page.search('//div[@class="rightMenu "]').remove
        libray_page.search('//div[@id="outofmain"]').remove
        libray_page.search('//a[@class="helpbtnarea"]').remove
        libray_page.search('//div[@class="backbtnarea pc_txt_shadow"]').remove
        libray_page.search('//div[@class="grid__row util__m0 util__mt20"]').remove
        
        delete_common_script(libray_page)

        libray_page.search("head script").last.remove # 謎の相対パス記述削除

        common_image_link_rewrite(libray_page)
        common_css_link_rewrite(libray_page)
        common_js_link_rewrite(libray_page)

        # linkの書き換え
        common_a_link_rewrite(libray_page)

        # アルバム一覧ページ保存
        output_file(libray_page, "library_page_" + libray_page_number.to_s + ".html")

        # mapping作成

        # break #TODO delete
        libray_page_number += 1
    end

    # cssが入れ子になっているため最低2回は動かす
    rewrite_css_file
    rewrite_css_file
end
