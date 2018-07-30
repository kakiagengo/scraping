# scraping

no support.  
未閲覧シーンが残っているヒロインではヒロイン個別ページのハートがロックされたまま保存されてしまいます。ただし、ロックされたアイコンを押せばシーンは閲覧できます。  
2回目は16行目の `$global_setting_heroine_mode = ` を `false` から `true` に変えて再度実行してください。
このモードでは、libraryページとヒロインの個別ページだけ取得しなおします。

# use

1. git & ruby & ruby gems install  
`sudo apt update;sudo apt install git ruby gem`  

2. nokogiri & mechanize install  
`sudo apt install ruby-nokogiri ruby-mechanize`  
or  
`sudo gem install nokogiri mechanize`

3. git clone 
`git clone --depth 1 https://github.com/kakiagengo/scraping.git`

4. edit session id  
chromeのF12 > Networkタブ参照

5. run  
改行コードが混じっているため、`./Scraping.rb`では実行しないでください。
`cd scraping`  
`ruby Scraping.rb`
