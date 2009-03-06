(in-package "PARENSCRIPT")

(defvar *html-empty-tag-aware-p* t)
(defvar *html-mode* :sgml "One of :sgml or :xml")

(defvar *html-empty-tags* '(:area :atop :audioscope :base :basefont :br :choose :col :frame
                            :hr :img :input :isindex :keygen :left :limittext :link :meta
                            :nextid :of :over :param :range :right :spacer :spot :tab :wbr))

(defun empty-tag-p (tag)
  (and *html-empty-tag-aware-p*
       (member tag *html-empty-tags*)))

(defun concat-constant-strings (str-list)
  (reverse (reduce (lambda (optimized-list next-obj)
                     (if (and (or (numberp next-obj) (stringp next-obj)) (stringp (car optimized-list)))
                         (cons (format nil "~a~a" (car optimized-list) next-obj) (cdr optimized-list))
                         (cons next-obj optimized-list)))
                   (cons () str-list))))

(defun process-html-forms-lhtml (forms)
  (let ((r ()))
    (labels ((process-attrs (attrs)
               (loop while attrs
                  for attr-name = (pop attrs)
                  for attr-test = (when (not (keywordp attr-name))
                                    (let ((test attr-name))
                                      (setf attr-name (pop attrs))
                                      test))
                  for attr-val = (pop attrs)
                  do
                    (if attr-test
                        (push `(if ,attr-test
                                   (concat-string ,(format nil " ~A=\"" attr-name) ,attr-val "\"")
                                   "")
                              r)
                        (progn
                          (push (format nil " ~A=\"" attr-name) r)
                          (push attr-val r)
                          (push "\"" r)))))
             (process-form% (tag attrs content)
               (push (format nil "<~A" tag) r)
               (process-attrs attrs)
               (if (or content (not (empty-tag-p tag)))
                   (progn (push ">" r)
                          (map nil #'process-form content)
                          (push (format nil "</~A>" tag) r))
                   (progn (when (eql *html-mode* :xml)
                            (push "/" r))
                          (push ">" r))))
             (process-form (form)
               (cond ((keywordp form) (process-form (list form)))
                     ((atom form) (push form r))
                     ((and (consp form) (keywordp (car form)))
                      (process-form% (car form) () (cdr form)))
                     ((and (consp form) (consp (first form)) (keywordp (caar form)))
                      (process-form% (caar form) (cdar form) (cdr form)))
                     (t (push form r)))))
      (map nil #'process-form forms)
      (concat-constant-strings (reverse r)))))

(defun process-html-forms-cl-who (forms)
  (let ((r ()))
    (labels ((process-form (form)
               (cond ((keywordp form) (process-form (list form)))
                     ((atom form) (push form r))
                     ((and (consp form) (keywordp (car form)))
                      (push (format nil "<~A" (car form)) r)
                      (labels ((process-attributes (el-body)
                                 (when el-body
                                   (if (or (consp (car el-body)) (= 1 (length el-body)))
                                       el-body
                                       (progn (push (format nil " ~A=\"" (car el-body)) r)
                                              (push (cadr el-body) r)
                                              (push "\"" r)
                                              (process-attributes (cddr el-body)))))))
                        (let ((content (process-attributes (cdr form))))
                          (if (or content (not (empty-tag-p (car form))))
                              (progn (push ">" r)
                                     (when content (map nil #'process-form content))
                                     (push (format nil "</~A>" (car form)) r))
                              (progn (when (eql *html-mode* :xml)
                                   (push "/" r))
                                 (push ">" r))))))
                     (t (push form r)))))
      (map nil #'process-form forms)
      (concat-constant-strings (reverse r)))))

(defmacro+ps ps-html (&rest html-forms)
  `(concat-string ,@(process-html-forms-lhtml html-forms)))

(defmacro+ps who-ps-html (&rest html-forms)
  `(concat-string ,@(process-html-forms-cl-who html-forms)))
