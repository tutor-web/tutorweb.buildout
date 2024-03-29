Tutor-web drill settings
^^^^^^^^^^^^^^^^^^^^^^^^

There are a bunch of key:value settings that can be used to control the
behaviour of the drill interface.

These can be set by doing one of:

* Editing the relevant tutorial
* Editing the relevant lecture
* Editing the defaults

For each lecture, the 2 lists of settings will be combined, the settings from a
lecture winning over any matching settings from a tutorial.

Core list of settings
=====================

Plone stores a list of all settings, and what their defaults should be. You can alter this by going here:

http://zoot:8080/portal_registry/edit/tutorweb.content.lectureSettings

A description of each settings follows.

Question assignment:

* ``question_cap``: The maximum number of questions of each question type that a student should be allocated. Default 100
* ``hist_sel``: Probability that a question from a previous lecture should be selected. Floating-point number ``[0,1]``. Default 0

Tutor/pupil chat:

* ``chat_competent_grade``: If a student gets a grade higher than this in a lecture, they can be a tutor. Default None

Coin awards for students:

* ``award_lecture_answered``: Milli-SMLY awarded for getting grade 5 in a lecture. Default 1000
* ``award_lecture_aced``: Milli-SMLY awarded for getting grade 10 in a lecture. Default 10000
* ``award_tutorial_aced``: Milli-SMLY awarded for getting grade 10 in every lecture. Default 100000
* ``award_templateqn_aced``: Milli-SMLY awarded for >= 50% of reviews of user-generated question positive. Default 10000
* ``award_registered_lecture_answered``: Deprecated: use registered variant. Default 1000
* ``award_registered_lecture_aced``: Deprecated: use registered variant. Default 10000
* ``award_registered_tutorial_aced``: Deprecated: use registered variant. Default 100000
* ``award_registered_templateqn_aced``: Milli-SMLY awarded for class-registered student >= 50% of reviews of user-generated question positive. Default 10000

Question template (i.e. crowdsourced questions) options:

* ``mingrade_template``: If a student's grade is lower than this, they never write/review template questions. Default 5
* ``prob_template``: Probability that a student will get a question template instead of a regular question. Default 0.1
* ``prob_template_eval``: Probability that a student, given they are getting a question template, they should evaluate someone elses efforts on that question. Default 0.8
* ``cap_template_qns``: Number of questions a student has to write in total. Default 5
* ``cap_template_qn_reviews``: Number of times a question needs to be reviewed. Default 10
* ``cap_template_qn_nonsense``: Number of times a question needs to be reviewed as nonsense before no more reviews are given. Default 10

Grading algorithm:

* ``grade_algorithm``: Grading algorithm to use. One of weighted, ratiocorrect. Default 'weighted'
* ``grade_nmin``: Minimum number of questions to consider during grading. Default 8
* ``grade_nmax``: Maximum number of questions to consdier during grading. Default 30
* ``grade_alpha``: Default 0.125
* ``grade_s``: Default 1

Question timeout:

* ``timeout_std``: Default 2
* ``timeout_min``: Lowest timeout for a question. In minutes. Default 3
* ``timeout_max``: Highest timeout for a question. In minutes. Default 10
* ``timeout_grade``: Grade that lower timeouts kick in. Default 5

Study Time (i.e. combined time spent on question and reading explanation):

  Study time = max(min(
      studytime_factor * (incorrect questions in a row) +
      studytime_answeredfactor * (# of questions answered including practice),
      studytime_max), studytime_baseline)

* ``studytime_factor``: Default 2
* ``studytime_answeredfactor``: Default 0
* ``studytime_max``: Maxiumum study time in seconds. Default 20
* ``studytime_baseline``: Minimum study time in seconds. Default 0

Practice Mode:

* ``practice_after``: Number of questions after which you can start practicing. Default 0
* ``practice_batch``: Number of practice questions you can do after "practice_after". Default Infinity

Allocation:

* ``iaa_type``: Which IAA algorithm to use on the client (adaptive or exam). Default 'adaptive'
* ``iaa_adaptive_gpow``: Default 1
* ``iaa_exam_finished_tmpl``: A templated string that will be shown at the end of an exam, you can include the following options. Default 'You have answered all questions...'
    ``${final_grade}`` - Final achieved grade
    ``${max_grade}`` - Maximum possible grade, i.e. 10.
    ``${failed_topics}`` - a list of titles
* ``allocation_method``: Which IAA algorithm to use on the server (original or exam). Default 'original'
* ``allocation_realloc_perc``: How many server allocations (oldest first) to throw away every 10 answers, as a percentage of ``question_cap``. Percentage ``[0,100]``. Default 20% (i.e. 20 questions with question_cap 100)

Randomly assigned settings
==========================

Any setting can have ``:min`` and ``:max`` postfixes (the interface will not show
all combinations though). If ``:max`` is set, then any time a student takes this
lecture, a random value with 3dp from 0 to ``:max`` will be assigned to them. In
addition, ``:min`` can be set to alter the lower bound. Just setting ``:min`` will
result in an error.

For example, setting ``grade_alpha:min`` to 0.1 and ``grade_alpha:max`` to 0.2
will mean a student will, when starting a lecture, be assigned a
``grade_alpha`` between 0.1 and 0.2. They will continue to use this value
whenever answering this question within a lecture.

Note that the ``_min`` in ``timeout_min`` is unrelated to ``:min``. A new timeout is
assigned per-question, not per-lecture. One could have ``timeout_max:max``, which
assigns a random maximum timeout for each student, but it's probably not that
useful.

Updating settings
=================

If any setting for a lecture is updated, then a student will start using that
new value once they sync their copy of the lecture, i.e. when they answer their
next question. In addition, if ``:min`` or ``:max`` is changed, then they will
be randomly assigned a new value between those bounds.

If students have finished working on that lecture then their settings will be
left unchanged. This means that historical data where students worked with
different values will be preserved.

Previewing a lecture's settings
===============================

Appending ``/@@drill-settings?pprint=1`` to a lecture URL will show the combination of
all lecture, tutorial and global settings. This is what will be used to
calculate a student's settings.

Exam lectures
=============

There are several settings that, whilst independent, all make sense for use with an exam:

* ``iaa_type`` should be set to 'exam': This ensures the student takes the questions in order
* ``allocation_method`` should be set to 'exam': This ensures the student's list of questions matches tutor-web, instead of a random allocation.
* ``grade_algorithm`` should be set to 'ratiocorrect': i.e. the grade is based entirely on how many questions are answered correctly.

Optionally ``iaa_exam_finished_tmpl`` could be set, see above.
