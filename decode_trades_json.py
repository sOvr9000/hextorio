
import json, base64, zlib
from pprint import pprint

fpath = 'PATH/TO/APP/DATA/Factorio/script-output/all-trades-encoded-json.txt' # Set the path

encoded_text = open(fpath, 'r').read()
decoded_text = zlib.decompress(base64.b64decode(encoded_text))
data = json.loads(decoded_text)

pprint(data['item_values']['nauvis']) # 'item_values' contains the adjusted value (per planet) for any item found in any discovered trade.
pprint(data['trades']['nauvis']) # 'trades' contains all discovered trades on all planets
