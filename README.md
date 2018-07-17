# scraping

# use

1. git & ruby & gem install  
`sudo apt update;sudo apt install git ruby gem`

2. install ruby gems  
`sudo gem install nokogiri mechanize`

3. git clone  
`git clone --depth 1 https://github.com/kakiagengo/scraping.git`

4. edit session id  
chromeのF12 > Networkタブ参照

5. run  
`cd scraping`
`ruby Scraping.rb | tee log.txt`
