Tutor-web drill settings
^^^^^^^^^^^^^^^^^^^^^^^^

There are a bunch of key:value settings that can be used to control the
behaviour of the drill interface.

These can be set by doing one of:

* Editing the relevant tutorial
* Editing the relevant lecture

For each lecture, the 2 lists of settings will be combined, the settings from a
lecture winning over any matching settings from a tutorial.

Core list of settings
=====================

Question assignment:
* `question_cap`: The maximum number of questions of each question type that a student should be allocated. Default 100

Coin awards for students:
* `award_lecture_answered`: Coins awarded for getting 8 questions correct. Default 1
* `award_lecture_aced`: Coins awarded for getting grade 10 in a lecture. Default 10
* `award_tutorial_aced` Coins awarded for getting grade 10 in every lecture. Default 100

Question template (i.e. crowdsourced questions) options:
* `prob_template`: Probability that a student will get a question template instead of a regular question. Default 0.1
* `prob_template_eval`: Probability that a student, given they are getting a question template, they should evaluate someone elses efforts on that question. Default 0.8

Grading algorithm:
* `grade_nmin`: Minimum number of questions to consider during grading. Default 8
* `grade_nmax`: Maximum number of questions to consdier during grading. Default 30
* `grade_alpha`: Default 0.125
* `grade_s`: Default 2

Question timeout:
* `timeout_std`: Default 2
* `timeout_min`: Lowest timeout for a question. In minutes. Default 3
* `timeout_max`: Highest timeout for a question. In minutes. Default 10
* `timeout_grade`: Grade that lower timeouts kick in. Default 5

Randomly assigned settings
==========================

Any setting can have `:min` and `:max` variants (the interface will not show
all combinations though). If `:max` is set, then any time a student takes this
lecture, a random value with 3dp 0..`:max` will be assigned to them. In
addition, `:min` can be set to alter the lower bound. Just setting `:min` will
result in an error.

Note that the `_min` in `timeout_min` is unrelated to `:min`. A new timeout is
assigned per-question, not per-lecture. One could have `timeout_max:max`, which
assigns a random maximum timeout for each student, but it's probably not that
useful.
