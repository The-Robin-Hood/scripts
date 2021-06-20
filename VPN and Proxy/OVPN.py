import os
import requests
import base64
import time 
def clrsc():
    if os.name == 'nt':
        os.system("cls")
    else:
        os.system("clear")

def main():
    print(Blue+"""             __/\__
            `==/\==`
  ____________/__\____________
 /__\u001b[31mAuthor : The_Robin_Hood\u001b[36m__\\ 
/_____________________________\\     
   __||__||__/.--.\__||__||__
  /__|___|___( >< )___|___|__\\
            _/`--`\_
           (/------\)"""+Reset)
    print(Yellow+"Choose Country : ")
    for index,i in enumerate(Countries):
        print(Green+f"\n{index+1}. {i}"+Reset)
        pairs = list(zip(labels, Collection[i]))[:-1]
        for (l, d) in pairs[1:4]:
            if l =='Score':
                continue
            print (l + ': ' + d)
        print (pairs[4][0] + ': ' + str(round(float(pairs[4][1]) / 10**6)) + ' MBps')

    try:
        Choosen = int(input("\n>>"))
    except KeyboardInterrupt:
        exit()
    except:
        clrsc()
        print(Red+" * Select Appropriate Number *\n"+Reset)
        main()
        exit()
        

    path = f"{Countries[Choosen-1]}.ovpn"
    print(Green+f"\nSaving as {path}"+Reset)
    try:
        with open(path,'x') as file:
            pass
    except:
        pass
    with open(path,'rb+') as file:
        file.write(base64.b64decode(Collection[Countries[Choosen-1]][-1]))
    time.sleep(3)
    clrsc()


vpn_data = requests.get('http://www.vpngate.net/api/iphone/').text.replace('\r','')
servers = [line.split(',') for line in vpn_data.split('\n')]
labels = servers[1]
labels[0] = labels[0][1:]
servers = [s for s in servers[2:] if len(s) > 1]
Countries = [s[5] for s in servers]
available =set()

for Country in Countries :
    available.add(Country)

Available_Countries = list(available)
Collection = {}

for country in Available_Countries:
    desired = [s for s in servers if country.lower() in s[5].lower()]
    found = len(desired)
    if found == 0:
        continue
    OpenVPN_Keys = [s for s in desired if len(s[-1]) > 0]

    Best = sorted(OpenVPN_Keys, key=lambda s: float(s[2].replace(',','.')), reverse=True)[0]
    Collection[country]=Best

Countries = list(Collection.keys())

Reset= '\u001b[0m'
Red= '\u001b[31m.'
Green= '\u001b[32m'
Yellow= '\u001b[33m'
Blue= '\u001b[36m'


clrsc()
main()


