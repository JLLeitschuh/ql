/*
 * Copyright (C) 2008 The Guava Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.google.common.collect;

public class ImmutableListMultimap<K, V> extends ImmutableMultimap<K, V> implements ListMultimap<K, V> {

  @Override
  public ImmutableList<V> get(K key) {
    return null;
  }

  /**
   * {@inheritDoc}
   *
   * <p>Because an inverse of a list multimap can contain multiple pairs with the same key and
   * value, this method returns an {@code ImmutableListMultimap} rather than the {@code
   * ImmutableMultimap} specified in the {@code ImmutableMultimap} class.
   *
   * @since 11.0
   */
  @Override
  public ImmutableListMultimap<V, K> inverse() {
    return null;
  }

  public final ImmutableList<V> removeAll(Object key) {
    return null;
  }

  public final ImmutableList<V> replaceValues(K key, Iterable<? extends V> values) {
    return null;
  }
}