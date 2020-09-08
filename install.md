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

## Voicemail
Several enhancements have been added to voicemail including SMS, callouts, and ZIP encryption of voicemail attachments

### ThinQ SMS
To enable ThinQ SMS for sending SMS voicemail notifications you need to add a few default settings

#### Default Settings

* Browse to **Advanced>>Default Settings**
* In the **Voicemail** section change/add the following settings:
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

### Additional Default Settings

* Browse to **Advanced>>Default Settings**
* In the **Voicemail** section change/add the following settings:
  * Subcategory: **company_name**
    * Type: text
    * Value: <YOUR_COMPANY_NAME>
    * Enabled: True


## Recording Management
The recording manamgement system requires phrases (referred to as prompts by the recording management system), recordings, and voicemail boxes to be set up with a particular numbering standard. Additionally, the PIN Numbers module must be activated using **Advanced>>Menu Manager**.

### Numbering Patterns
The following numbering standards apply:

#### Voicemail
Voicemails must be numbered in the format 3{ACCT} or 3{ACCT}X

* **{ACCT}** is the 4 digit zero padded client account number
* **XX** (optional) is the mailbox number from 01 to 99. If left off the mailbox number is 0

#### Recordings
Recordings must be numbered in the format {ACCT}-XXXX

* **{ACCT}** is the 4 digit zero padded account number
* **XXXX** is the prompt number from 0001 to 9999

#### Phrases
Phrases must be numbered in the format: {ACCT}-{TYPE}-XXX

* **{ACCT}** is the 4 digit zero padded account number
* **{TYPE}** is one of:
  * PREANSWER
    * These are prompts that are played while a caller is in queue but before the call has been answered by an agent
  * PREQUEUE
    * These are prompts played to a caller before being placed in queue
  * WHISPER
    * These are prompts that are played to the agent just before being connected to a caller
  * EMERG
    * These are reserved for when the system is placed in emergency mode
  * IVR
    * These are IVR prompts
* **XXX** is the phrase number from 001-999

### Default Settings
The following default settings need to be set in order for recording management functions to work properly:

* Browse to **Advanced>>Default Settings**
* In the **Recordings** section change/add the following settings:
  * Subcategory: **admin_acct**
    * Type: numeric
    * Value: <ANY_4_DIGIT_ACCT_NUMBER>
    * Enabled: True
    * Description: Administrative account for managing all system recordings
  * Subcategory: **emergency_mode**
    * Type: numeric
    * Value: 0
    * Enabled: True
    * Description: System emergency prompt mode
  * Subcategory: **vm_prefix**
    * Type: text
    * Value: <SINGLE_DIGIT_PREFIX>
    * Enabled: True
    * Description: Prefix for ALL voicemail boxes
  * Subcategory: **tts_voice**
    * Type: text
    * Value: Matthew
    * Enabled: True
    * Description: Text to speech voice to use for prompt management system

### PIN Numbers
With The PIN Numbers module enabled you can add entries for each user that will be managing recordings. To do this browse to **Applications>>PIN Numbers** and add users with the following settings:

* **PIN Number**: The PIN number for the user
* **Accountcode** The 4 digit zero padded account number that the user is allowed to manage, **OR** the administrative account code if they need to manage all prompts/recordings
* **Enabled**: True
* **Description**: User's full name

### Dialplan
Add a dialplan entry with the following settings to access the prompt management

* **Name**: prompt_mgmt
* **Number**: *733
* **Continue**: False
* **Enabled**: True

| Tag       | Type               | Data               | Break | Inline | Group | Order |
|-----------|--------------------|--------------------|-------|--------|-------|-------|
| condition | destination_number | `^\*(733)$`        |       |        | 0     | 5     |
| action    | answer             |                    |       |        | 0     | 10    |
| action    | lua                | app.lua promptmgmt |       |        | 0     | 20    |
