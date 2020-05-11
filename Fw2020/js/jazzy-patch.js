/*!
 * Syntax-highlighting patch for Bebop's jazzy compatibility mode
 *
 * Copyright 2020 Bebop Authors
 * Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
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
