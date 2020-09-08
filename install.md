# INSTALLATION
Installation is the same as FusionPBX standard release however a small change needs to be made to the installer before running. Additionally, using debian 10 in recommended

Run the following script to load the necessary files:

    wget -O - https://raw.githubusercontent.com/fusionpbx/fusionpbx-install.sh/master/debian/pre-install.sh | sh;

After this edit the file `/usr/src/fusionpbx-install.sh/debian/resources` and in the `#get the source code` section change the `git clone` line to the following:

    git clone $branch https://github.com/westparkcom/fusionpbx-wpc.git /var/www/fusionpbx

After modifying this file continue installation as normal.

# Additional Settings
Some additional settings will need to be set in order to utilize all of the features available in this repo. Perform these steps AFTER installing FusionPBX, and **ENSURE YOUR ARE RUNNING AS ROOT!!!**

## Install Python dependencies for Text To Speech
This repo uses Amazon Polly for text to speech. In order for this to work properly you will need to have a valid AWS account and have all of the prerequisites set up.

To install the python dependencies run the following commands:

    apt install freeswitch-mod-python ffmpeg python-pip python3-pip zip
    pip install boto3
    pip3 install boto3
    pip install ffmpy
    pip3 install ffmpy
    cp -r /var/www/fusionpbx/resources/install/python/* /usr/local/lib/python2.7/dist-packages
    cp -r /var/www/fusionpbx/resources/install/python/* /usr/local/lib/python3.7/dist-packages
    mkdir /var/lib/freeswitch/storage/tts
    chown -R www-data:www-data /var/lib/freeswitch/storage/tts
    chmod 0770 /var/lib/freeswitch/storage/tts

Once these files have been copied in you will need to modify the `/usr/local/lib/python*/dist-packages/fsglobs.py` files to add your AWS API keys

### Enable FreeSWITCH mod_python
To enable FreeSWITCH mod_python you will need to do so in the FusionPBX UI:

* Browse to **Advanced>>Modules**
* Browse AGAIN to **Advanced>>Modules** (this refreshes the module list)
* Find **Python** in the list and click it
* Modify it with the following settings:
  * Label: Python
  * Module Name: mod_python
  * Order: 800
  * Module Category: Languages
  * Enabled: True
  * Default Enabled: True

Once saved, refresh the page, find **Python** in the list of modules, then **Start** the module

## ThinQ SMS
To enable ThinQ SMS for sending SMS voicemail notifications you need to add a few default settings

* Browse to **Advanced>>Default Settings**
* Change/add the following settings:
  * Subcategory: **voicemail_to_sms**
    * Type: boolean
    * Value: true
    * Enabled: True
  * Subcategory: **voicemail_to_sms_did**
    * Type: text
    * Value: <DID_TO_SEND_SMS_FROM>
    * Enabled: True
  * Subcategory: **voicemail_sms_body**
    * Type: text
    * Value: This is the Messaging System. You have a new voicemail:\\n\\nCaller Name: ${caller_id_name}\\nCaller Number: ${caller_id_number}\\nTimestamp: ${message_date}\\nDuration: ${message_duration}\\n\\nTo manage your voicemail messages please dial XXX-XXX-XXXX
    * Enabled: True
  * Subcategory: **sms_thinq_acct**
    * Type: text
    * Value: <YOUR_THINQ_ACCT_NUMBER>
    * Enabled: True
  * Subcategory: **sms_thinq_username**
    * Type: text
    * Value: <YOUR_THINQ_USERNAME>
    * Enabled: True
  * Subcategory: **sms_thinq_token**
    * Type: text
    * Value <YOUR_THINQ_TOKEN>
    * Enabled: True
