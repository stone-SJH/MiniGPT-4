import argparse
import os
import random

import numpy as np
import torch
import torch.backends.cudnn as cudnn
import gradio as gr

from minigpt4.common.config import Config
from minigpt4.common.dist_utils import get_rank
from minigpt4.common.registry import registry
from minigpt4.conversation.conversation import Chat, Conversation, SeparatorStyle

# imports modules for registration
from minigpt4.datasets.builders import *
from minigpt4.models import *
from minigpt4.processors import *
from minigpt4.runners import *
from minigpt4.tasks import *

from flask import Flask, json, request
from gevent import pywsgi
import requests
from PIL import Image

def parse_args():
    parser = argparse.ArgumentParser(description="API")
    parser.add_argument("--cfg-path", required=True, help="path to configuration file.")
    parser.add_argument("--options", nargs="+", help="xxx")
    args = parser.parse_args()
    return args

# prepare conversation templates and prompt templates
CT_with_Image = Conversation(
    system="Give the following image: <Img>ImageContent</Img>. "
    "You will be able to see the image once I provide it to you. Please answer my questions.",
    roles=("Human", "Assistant"),
    messages=[],
    offset=2,
    sep_style=SeparatorStyle.SINGLE,
    sep="###",
)
print(CT_with_Image)

PROMPT_AssetLabeling = ("This is a picture of a 3D game model. Please generate exactly 6 tags for this asset according to this image. "
        "Pay attention to these constraints of tags:"
        "1. A Tag may contain one of the following features: the name of the asset, the color of the asset, the material of the asset, the category of the asset, the usage of the asset, the theme of the asset."
        "2. Output \"YahahaTags: \" first before tags."
        "3. Tags don’t contain background."
        "4. Tags don't contain \"Game Asset\",  \"Game Model\", \"3D Model\", \"3D Game Model\""
        #"5. The reference name of this asset is {AssetName}, Do not output this reference name as a tag directly. (Optional)"
)
print(PROMPT_AssetLabeling)

# initialize models
print('Initializing Chat')
api = Flask(__name__)
cfg = Config(parse_args())
model_config = cfg.model_cfg
model_cls = registry.get_model_class(model_config.arch)
model = model_cls.from_config(model_config).to('cuda:0')
vis_processor_cfg = cfg.datasets_cfg.cc_sbu_align.vis_processor.train
vis_processor = registry.get_processor_class(vis_processor_cfg.name).from_config(vis_processor_cfg)
chat = Chat(model, vis_processor)
print('Initalization Finished')



@api.route('/asset-labeling', methods=['POST'])
def conv_with_image():
    asset_name = "noname"
    img_url = "https://media-streaming.yahaha.com/mediaType/266ee4dc-e0a3-4def-a208-9e39adda14b6/d534b899568a9f84fbee1a3f179e0f68_3.png"
    beams = 5
    temperature = 1.0
    
    chat_state = CT_with_Image.copy()
    human_input = PROMPT_AssetLabeling
    img_list = []
    
    try:
        content = request.get_json(silent=True)
        asset_name = content['name']
        img_url = content['img_url']
        beams = content['nob']
        temperature = content['temperature']
        human_input = content['prompt']
        #print(img_url, beams, temperature)
        #print(human_input)
    except:
        human_input = PROMPT_AssetLabeling

    # embed image
    image = Image.open(requests.get(img_url, stream=True).raw).convert('RGB')
    # TODO: resize image if needed
    llm_message = chat.upload_img(image, chat_state, img_list)
    print(llm_message)
    
    # embed text prompts
    chat.ask(human_input, chat_state)

    # get result
    llm_message = chat.answer(conv=chat_state, img_list=img_list, max_new_tokens=1000, num_beams=beams, temperature=temperature)[0]

    print("**********AssetLabels:************")
    print(llm_message)
    print("**********************************")
    
    resp_data = {"message": llm_message}
    response = api.response_class(
        response=json.dumps(resp_data),
        status=200,
        mimetype='application/json')
    if chat_state is not None:
        chat_state.messages = []
    if img_list is not None:
        img_list = []
    return response

if __name__ == '__main__':
    server = pywsgi.WSGIServer(('0.0.0.0', 8004), api)
    server.serve_forever()
