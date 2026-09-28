'use server';

import { grantInventoryItem } from '@/app/users/actions';
import { findUserByQuery as findUser } from '@/app/staff/actions';

export async function findUserByQuery(query: string) {
  return findUser(query);
}

export async function grantShopItemToUser(
  userId: string,
  itemId: string,
  equip = true,
) {
  return grantInventoryItem(userId, itemId, { equip });
}
