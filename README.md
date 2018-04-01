# guacamole5

## Usage:

```
./script.sh -w watermark_file [-d dataset_dir | -D datasets_dir | -F dataset_file ] [-n dataset_name] [-r result_dir] [-f frame_length]
```

- -w - path to watermark image file, mandatory

Options to specify dataset(s). In order of priority:

- -F - path to file containing list of dataset paths
- -D - path to directory containing dataset sub-directories
- -d - path to the dataset directory
You should specify only one of options above

- -n - name of dataset (default value is name of directory of dataset)
- -r - resulting directory (default value is ./videos)
- -f - frame length (default value is 20 sec)

## Examples:
```
./script.sh -w dataset/watermark.png -d dataset/grison -f 2
./script.sh -w dataset/watermark.png -D dataset
./script.sh -w dataset/watermark.png -F datasets.txt
```

## Suggestions:
- Text file with list of steps must be named steps.txt and placed in dataset directory
	- Example: dataset/grison/steps.txt
- Text file must have one step per line
- Image files must be named as [dataset_name]-[frame_number].png
	- dataset_name - directory name or argument from switch -n
	- frame_number - number with leading 0 and starting from 1
	- Example: dataset/grison/grison-01.png
- Resulting video file will be saved as [result_dir]/[dataset_name].mp4
