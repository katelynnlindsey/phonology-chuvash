import yaml
import codecs

yaml_file = "chuvash-recode.yml"

print(f"--- Verifying content of '{yaml_file}' via Python ---")
try:
    with codecs.open(yaml_file, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    
    if isinstance(config, list):
        for rule in config:
            if 'conditions' in rule and isinstance(rule['conditions'], list):
                for condition in rule['conditions']:
                    if condition.get('attribute') == 'label' and 'set' in condition:
                        label_to_match = condition['set']
                        print(f"Rule: '{rule.get('rule', 'N/A')}', Target label: '{label_to_match}' (hex: {label_to_match.encode('utf-8').hex()}), Return: '{rule.get('return', 'N/A')}'")
    else:
        print("YAML file content is not a list of rules as expected.")

except FileNotFoundError:
    print(f"Error: '{yaml_file}' not found.")
except Exception as e:
    print(f"An unexpected error occurred while reading or parsing '{yaml_file}': {e}")