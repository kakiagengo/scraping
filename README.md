# scraping

no support.

# use

1. git & ruby & ruby gems install.  
`sudo apt update;sudo apt install git ruby gem`  

2. nokogiri & mechanize install.  
`sudo apt install ruby-nokogiri ruby-mechanize`  
or  
`sudo gem install nokogiri mechanize`

3. git clone 
`git clone --depth 1 https://github.com/kakiagengo/scraping.git`

4. edit session id.  
chromeのF12 > Networkタブ参照

5. run.  
`cd scraping`  
`ruby Scraping.rb | tee -a log.txt`
