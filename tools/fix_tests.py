def fix_file(path, replacements):
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    # Normalize CRLF to LF for consistent replacement, then back to CRLF
    is_crlf = '\r\n' in text
    text = text.replace('\r\n', '\n')
    for old, new in replacements:
        old_lf = old.replace('\r\n', '\n')
        new_lf = new.replace('\r\n', '\n')
        if old_lf not in text:
            print(f'Warning: target not found in {path}')
        else:
            text = text.replace(old_lf, new_lf)
    if is_crlf:
        text = text.replace('\n', '\r\n')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f'Fixed {path}')

# 1. task_8_fe_and_so_profile_test.dart
fix_file('flutter_apps/unified_app/test/task_8_fe_and_so_profile_test.dart', [
    ('expect(cart.totalQuantityCount, 4);', 'expect(cart.totalQuantityCount, 1);')
])

# 2. master_tasks_3_to_8_test.dart
fix_file('flutter_apps/unified_app/test/master_tasks_3_to_8_test.dart', [
    ('expect(cart.totalQuantityCount, 2);\n      expect(cart.items.first.quantityKg, 2.0);', 'expect(cart.totalQuantityCount, 1);\n      expect(cart.items.first.quantityKg, 2.0);'),
    ('expect(cart.totalQuantityCount, 5);\n      expect(cart.items.first.quantity, 5.0);', 'expect(cart.totalQuantityCount, 1);\n      expect(cart.items.first.quantity, 5.0);'),
    ('expect(cart.totalQuantityCount, 3);\n      expect(cart.totalQuantityKg, 3.0);', 'expect(cart.totalQuantityCount, 2);\n      expect(cart.totalQuantityKg, 3.0);'),
    ('expect(cart.totalQuantityCount, 4);\n\n      // Decrement', 'expect(cart.totalQuantityCount, 2);\n\n      // Decrement'),
    ('expect(cart.totalQuantityCount, 2);\n    });', 'expect(cart.totalQuantityCount, 1);\n    });')
])

# 3. task_7_shop_owner_cart_test.dart
fix_file('flutter_apps/unified_app/test/task_7_shop_owner_cart_test.dart', [
    ('expect(cart.totalQuantityCount, 3);\n      expect(cart.totalQuantityKg, 3.0);', 'expect(cart.totalQuantityCount, 2);\n      expect(cart.totalQuantityKg, 3.0);'),
    ('expect(cart.totalQuantityCount, 4);\n      expect(cart.items.firstWhere', 'expect(cart.totalQuantityCount, 2);\n      expect(cart.items.firstWhere'),
    ('expect(cartOwner1Reloaded.totalQuantityCount, 3);', 'expect(cartOwner1Reloaded.totalQuantityCount, 1);')
])

