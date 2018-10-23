require 'watir'
require 'colorize'

#NEED TO CREATE A FUNCTION TO OUTPUT OUTPUT FROM PERF AND PING TO A FILE

ssid = "165" #Box AP Number.
id_string_none = "%7B%22creatorUid%22%3A%221000%22%2C%22configKey%22%3A%22%5C%22108.1%5C%22NONE%22%7D" #Magic
id_string_wep = "%7B%22creatorUid%22%3A%221000%22%2C%22configKey%22%3A%22%5C%22108.1%5C%22WEP%22%7D"
id_string_wpa = "%7B%22creatorUid%22%3A%221000%22%2C%22configKey%22%3A%22%5C%22108.1%5C%22WPA_PSK%22%7D"
pass_wpa = "11111111" #8 Characters
pass_wep = "11111" #5 Characters
bgn_hash = {1 => "0", 2 => "1", 3 => "7", 4 => "2", 5 => "9", 6 => "10"}
auth_hash = {1 => "none", 2 => "wep", 3 => "wpa_soho", 4 => "wpa2_soho", 5 => "wpa_wpa2_soho"}

#This just gets the DUT's IP.
strip = `adb shell getprop | findstr address` #Gets raw return to parse for IP address for variable DUT_IP
strip.strip!
a = strip.split(']')
dut_ip = a[1]
dut_ip[0..2] = '' #Removes first two characters of the string.

def reset_dut()
`adb shell am broadcast -a "android.intent.action.MASTER_CLEAR" --receiver-permission "android.permission.MASTER_CLEAR"`
puts "LET ME KNOW WHEN YOU RESET THE DUT BY PRESSING 'ENTER'! :)".green
gets
end

def create_wpa_supplicant(ssid, pass_wpa, pass_wep, id_string_none, id_string_wep, id_string_wpa)
`del wpa_supplicant.conf`
`adb shell svc wifi disable` #Disables WiFi.
puts "WiFi is DOWN".red
`adb shell rm /data/misc/wifi/wpa_supplicant.conf 2>/dev/null` #Removes current wpa_supplicant.conf
`adb shell chown system.wifi /data/misc/wifi/wpa_supplicant.conf` #Magic
`adb shell chmod 660 /data/misc/wifi/wpa_supplicant.conf` #Voodoo
`adb pull /data/misc/wifi/wpa_supplicant.conf`
output = File.open( "wpa_supplicant.conf","a" )
output << "network={
	ssid=#{ssid}
	psk=#{pass_wpa}
	key_mgmt=WPA-PSK
	priority=9
	id_str=#{id_string_wpa}
}

network={
	ssid=#{ssid}
	key_mgmt=NONE
	auth_alg=OPEN SHARED
	wep_key0=#{pass_wep}
	priority=14
	id_str=#{id_string_wep}
}

network={
	ssid=#{ssid}
	key_mgmt=NONE
	priority=15
	id_str=#{id_string_none}
}"
output.close
puts "WPA_supplicant.conf created.".blue
`adb shell svc wifi enable` #Enables WiFi again.
puts "WiFi is UP".red
sleep(30)
end

def iptables_setup()
`adb shell iptables -A INPUT -j ACCEPT`
`adb shell iptables -A OUTPUT -j ACCEPT`
`adb shell iptables -A FORWARD -j ACCEPT`
puts "IPTables set.".blue
end

def reset_and_setup_ap()
browser = Watir::Browser.new
browser.goto "http://guest:guest@192.168.1.1"
browser.element(:xpath,"//*[@id='left_main_menu_entrysystem_misc_config']").click #Click System Tools.
browser.element(:xpath,"//*[@id='system_restore_default_config43']").click #Click Factory Defaults.
browser.button(:xpath, "//*[@id='RestoreDefault_form']/table/tbody/tr[2]/td/input[2]").click #Click Restore.
sleep(35) #Waits for reset to complete.
browser.close

browser = Watir::Browser.new
browser.goto "http://guest:guest@192.168.1.1"
browser.element(:xpath,"//*[@id='left_main_menu_entrywireless_config']").click #Click Wireless
sleep(4)
browser.text_field(:xpath, "//*[@id='wireless_base_network_name']").set "165" #Enter new SSID.
sleep(3)
browser.button(:xpath, "//*[@id='wireless_base_form']/table[2]/tbody/tr/td/input").click #Save changes.
browser.close
puts "AP Reset and configured.".blue
sleep(20)
end

#Function for doing iPerf Checks, define in seconds.
def iperf_s(dut_ip, seconds)

hangup = `iperf.exe -c #{dut_ip} -l8K -w8M -fm -i1 -t#{seconds} -r` #Will return the output of the iperf test to DUT to a screen for review.
puts "Waiting on PERF"
sleep(10)
puts "This is the IP - #{dut_ip}"
puts hangup

end

def connect_to_wifi()

`adb shell svc wifi disable` #Disables WiFi.
puts "WiFi is DOWN".red
`adb rm /data/misc/wifi/wpa_supplicant.conf 2>/dev/null` #Removes current wpa_supplicant.conf
`adb push wpa_supplicant.conf /data/misc/wifi/wpa_supplicant.conf` #Pushes new wpa_supplicant.conf we generated.
`adb shell chown system.wifi /data/misc/wifi/wpa_supplicant.conf` #Magic
`adb shell chmod 660 /data/misc/wifi/wpa_supplicant.conf` #Voodoo
`adb shell svc wifi enable` #Enables WiFi again.
puts "WiFi is UP".red
sleep(30)

end

#Function for doing Ping Check on DUT connection to WiFi
def ping_check()
k = `adb shell ping -c 4 8.8.8.8` #Put Ping output into k

#Check if the internet is available or if the packet loss was total.

if k.include?("unreachable")
	puts "BROKEN!!!".yellow
elsif k.include?("100% packet loss")
	puts "BROKEN!!!".yellow
end

l = k.split("\n") #Split up k into l along the '\n'.
ping_output = l[7..8].to_s # Put the result into a variable to output.
puts ping_output.green
end

def tkip_aes_selection(browser, auth_hash, j)
for m in 0..2
sleep(4)
browser.select_list(:xpath, "//*[@id='wls_ap_mode_sel']").select_value auth_hash[j]
sleep(4)
c = browser.radios(:name, "ap_wpa_tkaes") # Find TKIP element.
c[m].click #Set to TKIP, AES, TKIP & AES.
browser.text_field(:xpath, "//*[@id='ap_wpa_key_val_id']").set "11111111" #Enter the password.
browser.button(:xpath, "//*[@id='wireless_sec_ap_form']/table[3]/tbody/tr/td/input").click #Save changes.
sleep(30)

connect_to_wifi()
ping_check()
end
end

reset_dut() #Factory Reset DUT.
reset_and_setup_ap() #Setup the AP.
iptables_setup() #Initialize IP Tables as needed.
create_wpa_supplicant(ssid, pass_wpa, pass_wep, id_string) #Pull and update wpa_supplicant.conf

for i in 1..bgn_hash.size

browser = Watir::Browser.new
browser.goto "http://guest:guest@192.168.1.1"
browser.element(:xpath,"//*[@id='left_main_menu_entrywireless_config']").click #Click Wireless
sleep(4)
browser.select_list(:xpath, "//*[@id='wireless_base_band_sel']").select_value bgn_hash[i] #Set to the i value of bgn_hash
sleep(4)
browser.button(:xpath, "//*[@id='wireless_base_form']/table[2]/tbody/tr/td/input").click #Save the settings
puts "AP Rebooting, hold on!"
sleep(30)

connect_to_wifi()
ping_check()
browser.close

end


#Standard WEP/WPA Speed Tests.
for j in 1..auth_hash.size
browser = Watir::Browser.new
browser.goto "http://guest:guest@192.168.1.1"
browser.element(:xpath,"//*[@id='left_main_menu_entrywireless_config']").click #Click Wireless
browser.element(:xpath,"//*[@id='wireless_Security_config11']").click #Click Wirelss Security
puts j

if j == 1
#No Security
sleep(4)
browser.select_list(:xpath, "//*[@id='wls_ap_mode_sel']").select_value auth_hash[j] #None security.
sleep(4)
browser.button(:xpath, "//*[@id='wireless_sec_ap_form']/table[3]/tbody/tr/td/input").click #Save
puts "AP Rebooting, hold on!"
sleep(30)
browser.close
connect_to_wifi()
ping_check()

elsif j == 2
#Wep Security
sleep(4)
browser.select_list(:xpath, "//*[@id='wls_ap_mode_sel']").select_value auth_hash[j]
sleep(4)
browser.text_field(:xpath, "//*[@id='ap_wep_key']").set "11111" #Wep only allows 5 characters.
browser.button(:xpath, "//*[@id='wireless_sec_ap_form']/table[3]/tbody/tr/td/input").click #Save
puts "AP Rebooting, hold on!"
sleep(30)
browser.close
connect_to_wifi()
ping_check()

elsif j == 3
#WPA Security
tkip_aes_selection(browser, auth_hash, j)
browser.close

elsif j == 4

#WPA2 Security
tkip_aes_selection(browser, auth_hash, j)
browser.close

elsif j == 5
#WPA2/WPA Security
tkip_aes_selection(browser, auth_hash, j)
browser.close

end
end

puts "Completed AP-165 bandwidth test."
