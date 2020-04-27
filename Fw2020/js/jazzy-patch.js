/*!
 * J2 syntax-highlighting patch for jazzy compatibility themes
 *
 * Copyright 2020 J2 Authors
 * Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
 */

/* global Prism */

'use strict'

/*
 * Prism customization for CSS tag names.
 */
Prism.plugins.customClass.map((className, language) => {
  return 'pr-' + className
})

/*
 * Prism customization for autoloading missing languages.
 */
Prism.plugins.autoloader.languages_path = 'https://cdnjs.cloudflare.com/ajax/libs/prism/1.17.1/components/'
