# -*- coding: utf-8 -*-
import freeswitch
import os
import fsglobs
reload(fsglobs)
from fsglobs import G

def ttsgen(text, voice):
	import polly
	reload(polly)
	from polly import AWSPolly
	polly_voice = AWSPolly(
		G.aws_access_key,
		G.aws_secret_key,
		G.aws_region_name
	)
	ssml_text = "<speak><prosody rate=\"-5%\">{}</prosody></speak>".format(
		text
	)
	result, fname = polly_voice.genspeech(
		ssml_text,
		voice,
		G.tts_location
	)
	if not result:
		freeswitch.consoleLog(
			"err",
			"Unable to generate text to speech: {}".format(
				fname
			)
		)
		return "null.wav"
	else:
		return fname
		

def fsapi(session, stream, env, args):
	argsarr = args.split("|")
	if len(argsarr) < 1 or len(argsarr) > 2:
		freeswitch.consoleLog(
			"err",
			"Invalid arguments specified. Use: voice=Joanna|text=\"This is text to speech.\"\n"
		)
		return 1
	arg0 = argsarr[0].split("=", 1)
	if len(argsarr) == 2:
		arg1 = argsarr[1].split("=", 1)
	else:
		if arg0[0] != 'text': #This means only one arg was passed, and it wasn't text
			freeswitch.consoleLog(
				"err",
				"Invalid arguments specified. Use: voice=Joanna|text=\"This is text to speech.\"\n"
			)
			return 1
		else:
			arg1 = ['voice', G.tts_default_voice]
	argsdict = {
		arg0[0]: arg0[1],
		arg1[0]: arg1[1]
	}
	if 'voice' in argsdict and 'text' in argsdict:
		stream.write(
			ttsgen(
				argsdict['text'],
				argsdict['voice']
			)
		)
		return 0
	else:
		freeswitch.consoleLog(
			"err",
			"Invalid arguments specified. Use: voice=Joanna|text=\"This is text to speech.\"\n"
		)
		return 1
