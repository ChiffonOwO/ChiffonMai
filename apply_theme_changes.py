#!/usr/bin/env python3
"""Apply theme color replacements to SongInfoPage.dart"""
import re

filepath = r'd:\flutterProjects\my_first_flutter_app\lib\page\SongInfoPage.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')

# Line 6082 boundary (1-indexed)
BOUNDARY = 6082

# Build new content
new_lines = []

for i, line in enumerate(lines):
    line_num = i + 1

    if line_num > BOUNDARY:
        new_lines.append(line)
        continue

    # =========================================================
    # 1. Bare Colors.grey
    # =========================================================
    # Shadows: .withOpacity(0.1)
    line = line.replace(
        'Colors.grey.withOpacity(0.1)',
        'AppColors.greyHint(brightness).withOpacity(0.1)')
    # Button bg
    line = line.replace(
        'backgroundColor: Colors.grey,',
        'backgroundColor: AppColors.greyHint(brightness),')
    # TextStyle: color: Colors.grey), or color: Colors.grey,
    line = re.sub(r'color: Colors\.grey([,\)])',
                  r'color: AppColors.secondaryText(brightness)\1', line)
    # color: Colors.grey at end of line
    line = re.sub(r'color: Colors\.grey$',
                  r'color: AppColors.secondaryText(brightness)', line)
    # Icon color
    line = re.sub(r'(Icons\.\w+,\s*size:\s*\d+,\s*color:\s*)Colors\.grey([,\)\s])',
                  r'\1AppColors.secondaryText(brightness)\2', line)
    # Ternary: : Colors.grey) or : Colors.grey,
    line = re.sub(r': Colors\.grey([,\)])',
                  r': AppColors.secondaryText(brightness)\1', line)

    # =========================================================
    # 2. Colors.black87
    # =========================================================
    line = line.replace('Colors.black87',
                       'Theme.of(context).colorScheme.onSurface')

    # =========================================================
    # 3. Colors.black12 -> conditional
    # =========================================================
    line = line.replace('Colors.black12',
                       'Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12')

    # =========================================================
    # 4. Colors.black as text color
    # =========================================================
    # Color ratingColor = Colors.black;
    if 'Color ratingColor = Colors.black;' in line:
        line = line.replace(
            'Color ratingColor = Colors.black;',
            'Color ratingColor = Theme.of(context).colorScheme.onSurface;')
    # : Colors.black,  (ternary)
    line = re.sub(r': Colors\.black,($|\s)',
                  r': Theme.of(context).colorScheme.onSurface,', line)
    # : Colors.black)  (ternary at end)
    line = re.sub(r': Colors\.black\)',
                  r': Theme.of(context).colorScheme.onSurface)', line)
    # color: Colors.black),  (TextStyle)
    line = re.sub(r'color: Colors\.black([,\)])',
                  r'color: Theme.of(context).colorScheme.onSurface\1', line)
    # color: Colors.black$  (TextStyle at end)
    line = re.sub(r'color: Colors\.black$',
                  r'color: Theme.of(context).colorScheme.onSurface', line)

    # =========================================================
    # 5. Colors.white in BoxDecoration
    #    Only replace if preceded by BoxDecoration( within ~5 lines
    #    and this line is exclusively "color: Colors.white," (with indentation)
    # =========================================================
    if re.match(r'^\s+color: Colors\.white,?\s*$', line):
        # Look back up to 10 lines for 'BoxDecoration(' or 'decoration:'
        found_decoration = False
        for j in range(max(0, i-10), i):
            if 'BoxDecoration(' in lines[j] or 'decoration:' in lines[j]:
                found_decoration = True
                break
        # Also check if NOT a TextStyle/ForegroundColor/Icon context
        # by checking if 'TextStyle' or 'foregroundColor' appears on this line
        is_text_style = 'TextStyle' in line or 'foregroundColor' in line
        if found_decoration and not is_text_style:
            line = line.replace('Colors.white',
                              'Theme.of(context).colorScheme.surface')

    new_lines.append(line)

result = '\n'.join(new_lines)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(result)

print("Done! Applied all theme color replacements before line 6082.")
