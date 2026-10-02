# Analyze union songs vs maidata index to find missing maidata
# Run with: python analyze_maidata.py

import json
import sys
import re

UNION_PATH = 'assets/others/unionresponse.json'
INDEX_URL = 'https://chiffonmai.cloud/index.json'
INDEX_LOCAL = r'C:\Users\user\AppData\Local\Temp\dsh-index.json'

def load_index():
    with open(INDEX_LOCAL, 'r', encoding='utf-8-sig') as f:
        raw = f.read()
    # index.json keys are shortId (string), values are titles
    return json.loads(raw)

def parse_ut_chart_id(ut_chart):
    """UTAGE chart has id field directly"""
    return str(ut_chart['id'])

def analyze_song(song, index_data):
    """For a given union song, determine which variants have/don't have maidata"""
    sid = str(song['id'])
    title = song['title']
    has_dx = song.get('hasDx', False)
    has_sd = song.get('hasSd', False)
    has_ut = song.get('hasUt', False)
    is_m2l = song.get('m2l', False)
    genre = song.get('genre', '')

    # Skip Mai2Link custom charts (m2l) — they don't have real maidata shortIds
    # Also skip 自制谱 genre
    if is_m2l or genre == '自制谱':
        return None

    result = {
        'id': song['id'],
        'title': title,
        'missing': [],
        'present': [],
        'has_dx': has_dx,
        'has_sd': has_sd,
        'has_ut': has_ut,
    }

    # SD
    if has_sd and 'sd' in song and song['sd']:
        # take any SD chart as representative
        sd_keys = list(song['sd'].keys())
        if sd_keys:
            sd_chart = song['sd'][sd_keys[0]]
            sd_id = str(sd_chart['id'])
            if sd_id in index_data:
                result['present'].append(('SD', sd_id, index_data[sd_id]))
            else:
                result['missing'].append(('SD', sd_id))

    # DX
    if has_dx and 'dx' in song and song['dx']:
        dx_keys = list(song['dx'].keys())
        if dx_keys:
            dx_chart = song['dx'][dx_keys[0]]
            dx_id = str(dx_chart['id'])
            if dx_id in index_data:
                result['present'].append(('DX', dx_id, index_data[dx_id]))
            else:
                result['missing'].append(('DX', dx_id))

    # UTAGE - via utTitle map
    if has_ut and 'utTitle' in song and song['utTitle']:
        for ut_id_str, ut_title in song['utTitle'].items():
            if ut_id_str in index_data:
                result['present'].append(('UTAGE', ut_id_str, index_data[ut_id_str]))
            else:
                result['missing'].append(('UTAGE', ut_id_str))

    return result

def main():
    import sys
    sys.stdout.reconfigure(encoding='utf-8')

    with open(UNION_PATH, 'r', encoding='utf-8') as f:
        union = json.load(f)

    index_data = load_index()
    print(f'Loaded union songs: {len(union)}', file=sys.stderr)
    print(f'Loaded index entries: {len(index_data)}', file=sys.stderr)

    missing_total = []
    skipped_total = 0
    for song in union:
        res = analyze_song(song, index_data)
        if res is None:
            skipped_total += 1
            continue
        if res['missing']:
            missing_total.append(res)

    print(f'\n=== Songs with missing maidata: {len(missing_total)} ===', file=sys.stderr)
    print(f'=== Skipped (m2l/自制谱): {skipped_total} ===\n', file=sys.stderr)

    # Group by variant for summary
    missing_by_variant = {'SD': [], 'DX': [], 'UTAGE': []}
    for song in missing_total:
        for variant, short_id in song['missing']:
            missing_by_variant[variant].append((song['id'], song['title'], short_id))

    # Print details
    for song in missing_total:
        song_missing_strs = [f'{v}={sid}' for v, sid in song['missing']]
        print(f"[id={song['id']}] {song['title']}  (hasDx={song['has_dx']}, hasSd={song['has_sd']}, hasUt={song['has_ut']})")
        if song['missing']:
            print(f"  缺失 maidata: {', '.join(song_missing_strs)}")
        if song['present']:
            present_strs = [f'{v}={sid}({title})' for v, sid, title in song['present']]
            print(f"  已有 maidata: {', '.join(present_strs)}")
        print()

    # Save to file
    out_path = r'C:\Users\user\AppData\Local\Temp\missing_maidata.txt'
    with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(f'=== Union 全量歌曲 maidata 缺失报告 ===\n')
        f.write(f'  Union 总歌曲数: {len(union)}\n')
        f.write(f'  已过滤 m2l/自制谱: {skipped_total}\n')
        f.write(f'  待检查: {len(union) - skipped_total}\n')
        f.write(f'  缺失 maidata 的歌曲数: {len(missing_total)}\n')
        f.write(f'  缺失条目总数: {sum(len(song["missing"]) for song in missing_total)}\n\n')

        for variant in ['SD', 'DX', 'UTAGE']:
            items = missing_by_variant[variant]
            f.write(f'--- 缺失 {variant}: {len(items)} 首 ---\n')
            for sid, title, short_id in items:
                f.write(f'  id={sid:>6}  {title}  (缺失 shortId={short_id})\n')
            f.write('\n')
    print(f'\nSaved report to {out_path}', file=sys.stderr)

    # Summary by variant
    print('\n=== 缺失汇总 ===', file=sys.stderr)
    for variant, items in missing_by_variant.items():
        print(f'  {variant}: 缺失 {len(items)} 首', file=sys.stderr)
    print(f'  总计: {sum(len(v) for v in missing_by_variant.values())} 项缺失', file=sys.stderr)

    return missing_total, missing_by_variant

if __name__ == '__main__':
    main()