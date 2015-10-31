#
#
# A Genyris script to control the Aviosys IP Power 9202 from the command-line.
#
# USAGE:
#
#   genyris ippower.g serverURL username password Port1 Port2 Port3 Port3"
# 
#       e.g. genyris ippower.g http://ippower admin 12345678 On On Off Off"
#
#
# This code tested on Genyris 0.9.3-14-g356de25-8, 
# this or a later version is be requried.
#
#  Genyris obtainable from GitHub & Sourceforge: 
#     http://sourceforge.net/projects/genyris/
#
# 
@prefix u   "http://www.genyris.org/lang/utilities#"
@prefix web "http://www.genyris.org/lang/web#"
@prefix sys "http://www.genyris.org/lang/system#"
@prefix task "http://www.genyris.org/lang/task#"


#
# From the ippower login page:
#     <script LANGUAGE="javascript" TYPE="text/javascript">
#     function calcResponse() {
#         str = document.login.Username.value + 
#             document.login.Password.value +
#             document.login.Challenge.value;
# 
#         document.login.Response.value = hex_md5(str);
#         document.login.Password.value = "";
#         document.login.Challenge.value = "";
#         document.login.submit();
#     }
#</script>
#
def calcResponse (username password challenge)
    # Function same as on the page see above
    define str (""(.join (list username password challenge)))
    (Reader!new str)
       .digest "MD5"
       
def failonerror( error )
    cond
        error
            print error
            sleep 100
            os!exit 1

def ippowerIOcontrol(serverURL username password Port1 Port2 Port3 Port4)
    #
    # Login to the ippower...
    #
    display "Login...\n" 
    define content nil
    catch error       
        setq content
            (left (web:get serverURL nil '1.0'))
                .readAll
    failonerror error

    # Look for <input TYPE="hidden" NAME="Challenge" VALUE=\n"3DQ6....">
    define challenge
       nth 1
           (content(.replace '\n' ' '))
               .regex 'NAME="Challenge"[ \s]+VALUE=[ \s]+"([^"]+)"'
    cond
        (null? challenge)
            print "Failed to parse Challenge"
            os!exit 1
    display ("Login challenge: %s\n"(.format challenge)) 
    var responseToChallenge 
        calcResponse username password challenge

    # Now POST the login...
    catch error
        var loginResponse
            web:post ('%a/tgi/login.tgi'(.format serverURL))
                template
                    (Username = 'admin')
                        Password = ''
                        Challenge = ''
                        Response = $responseToChallenge
                nil
                ~ '1.0'
    failonerror error
    # Login responds with: 
    #   Set-Cookie: Taifatech=PZ/Q; path=/
    var loginResponseHeaders
        tag Alist
            nth 1 loginResponse
            
    # Look for Taifatech cookie
    var cookie # e.g. 'Taifatech=4j1R; path=/'
        loginResponseHeaders (.lookup 'Set-Cookie')
    cond
        (null? cookie)
            print "Failed to find Taifatech cookie,"
            print "Incorrect username or password."
            os!exit 1

    var cookieNameValue # e.g. ^('Taifatech' '4j1R')
        (left (cookie(.split ';')))
            .split '='

    assertEqual (left cookieNameValue) 'Taifatech'

    var securityCookieValue   # e.g. '4j1R'
        nth 1 cookieNameValue
    display ("Login response cookie: %s\n"(.format securityCookieValue)) 

    #
    # Now POST the I/O control values...
    #
    # tgi/ioControl.tgi
    #
    # ioControl.tgi sends:
    #   Cookie: Taifatech=PZ/Q
    #
    define formData
        template
           ('PinNo' = 'P6_0')
            'P60' = $Port1 
            'P60_TIMER' = '0'
            'P60_TIMER_CNTL' = 'On'
            'PinNo' = 'P6_1'
            'P61' = 'On'
            'P61_TIMER' = '0'
            'P61_TIMER_CNTL' = 'On'
            'PinNo' = 'P6_2'
            'P62' = $Port2
            'P62_TIMER' = '0'
            'P62_TIMER_CNTL' = 'On'
            'PinNo' = 'P6_3'
            'P63' = 'On'
            'P63_TIMER' = '0'
            'P63_TIMER_CNTL' = 'On'
            'PinNo' = 'P6_4'
            'P64' = 'On'
            'P64_TIMER' = '0'
            'P64_TIMER_CNTL' = 'On'
            'PinNo' = 'P6_5'
            'P65' = $Port3
            'P65_TIMER' = '0'
            'P65_TIMER_CNTL' = 'Off'
            'PinNo' = 'P6_6'
            'P66' = 'On'
            'P66_TIMER' = '0'
            'P66_TIMER_CNTL' = 'On'
            'PinNo' = 'P6_7'
            'P67' = $Port4
            'P67_TIMER' = '0'
            'P67_TIMER_CNTL' = 'On'
            'Apply' = 'Apply'

    var ioControlHeaders
        template (('Cookie' = $('Taifatech=%s' (.format securityCookieValue))))

    display ("IO Control...%s %s %s %s\n"(.format Port1 Port2 Port3 Port4))
    #
    # Now do the POST
    #
    catch error
        var ioControlresponse
            web:post ('%a/tgi/ioControl.tgi'(.format serverURL)) formData ioControlHeaders '1.0'
            # FYI - Actually the Aviosys 9202 ignores the security cookie in ioControlHeaders!
            #       Which means the device is totally insecure. However we will do the login
            #       and pass the cookie in case a different version of firmware 
            #       does not have the vurnerability. 
    failonerror error
#
#  Main...
#
cond
   (and sys:argv (equal? (task:id)!name 'main'))
        cond
            (not (equal? 8 (length sys:argv)))
                print "Usage: genyris ippower.g serverURL username password Port1 Port2 Port3 Port3"
                print "   e.g. genyris ippower.g http://ippower admin 12345678 On On Off Off"
                print sys:argv
                os!exit 1
                
        var serverURL (nth 1 sys:argv) 
        var username (nth 2 sys:argv) 
        var password (nth 3 sys:argv) 
        var Port1 (nth 4 sys:argv) 
        var Port2 (nth 5 sys:argv) 
        var Port3 (nth 6 sys:argv) 
        var Port4 (nth 7 sys:argv) 

        ippowerIOcontrol serverURL username password Port1 Port2 Port3 Port3







       
    
