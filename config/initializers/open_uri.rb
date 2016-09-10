# force open-uri to create a tmp file.
# without these, files of <10Kb will return a StringIO instead of a file.
OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0
