import 'package:flutter/cupertino.dart';

import '../../../../core/models/choice_option.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/form_image.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/models/question.dart';
import '../../../../core/models/question_kind.dart';

class FormTemplate {
  final String title;
  final String category;
  final String imagePath;
  final IconData icon;
  final List<Item> items;
  final bool quizMode;

  const FormTemplate({
    required this.title,
    required this.category,
    required this.imagePath,
    required this.icon,
    required this.items,
    this.quizMode = false,
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Item _q(String id, String title, QuestionKind kind, {bool required = false}) =>
    Item(
      itemId: id,
      title: title,
      content: QuestionItemContent(
        question: Question(questionId: 'q$id', required: required, kind: kind),
      ),
    );

ChoiceQuestion _radio(List<String> options) => ChoiceQuestion(
      type: ChoiceType.radio,
      options: options.map((v) => ChoiceOption(value: v)).toList(),
    );

ChoiceQuestion _checkbox(List<String> options) => ChoiceQuestion(
      type: ChoiceType.checkbox,
      options: options.map((v) => ChoiceOption(value: v)).toList(),
    );

const _text = TextQuestion();
const _paragraph = TextQuestion(paragraph: true);

// ── Work ──────────────────────────────────────────────────────────────────────

final _contactInfo = FormTemplate(
  title: 'Contact information',
  category: 'Work',
  imagePath: 'assets/template_image/contact_information.png',
  icon: CupertinoIcons.phone,
  items: [
    _q('1', 'Name', _text, required: true),
    _q('2', 'Email', _text, required: true),
    _q('3', 'Address', _paragraph, required: true),
    _q('4', 'Phone number', _text),
    _q('5', 'Comments', _paragraph),
  ],
);

final _customerFeedback = FormTemplate(
  title: 'Customer Feedback',
  category: 'Work',
  imagePath: 'assets/template_image/customer_feedback.png',
  icon: CupertinoIcons.chat_bubble_text,
  items: [
    _q('1', 'Feedback Type',
        _radio(['Comments', 'Questions', 'Bug Reports', 'Feature Request'])),
    _q('2', 'Feedback', _paragraph, required: true),
    _q('3', 'Suggestions for improvement', _paragraph),
    _q('4', 'Name', _text),
    _q('5', 'Email', _text),
  ],
);

final _workRequest = FormTemplate(
  title: 'Work Request',
  category: 'Work',
  imagePath: 'assets/template_image/work_request.png',
  icon: CupertinoIcons.wrench,
  items: [
    Item(
      itemId: 'ti1',
      title: 'Personal info',
      content: const TextItemContent(),
    ),
    _q('1', 'Name', _text, required: true),
    _q('2', 'Email address', _text, required: true),
    Item(
      itemId: 'ti2',
      title: 'Describe the problem',
      content: const TextItemContent(),
    ),
    _q('3', 'Summary', _text, required: true),
    _q('4', 'Location of problem', _text, required: true),
    _q('5', 'Type',
        ChoiceQuestion(
          type: ChoiceType.radio,
          options: [
            ChoiceOption(value: 'Plumbing'),
            ChoiceOption(value: 'Lighting'),
            ChoiceOption(value: 'Heat/AC'),
            ChoiceOption(value: 'Pests'),
            ChoiceOption(value: 'Security'),
            ChoiceOption(value: 'Noise'),
            ChoiceOption(value: '', isOther: true),
          ],
        ),
        required: true),
    _q('6', 'Priority',
        const ScaleQuestion(low: 1, high: 5, lowLabel: 'Very high', highLabel: 'Very low'),
        required: true),
    _q('7', 'Due date', const DateQuestion()),
    _q('8', 'More details', _paragraph),
  ],
);

final _orderForm = FormTemplate(
  title: 'Order Request',
  category: 'Work',
  imagePath: 'assets/template_image/order_form.png',
  icon: CupertinoIcons.cart,
  items: [
    _q('1', 'Are you a new or existing customer?',
        _radio(['I am a new customer', 'I am an existing customer'])),
    _q('2', 'What is the item you would like to order?', _text, required: true),
    _q('3', 'What color(s) would you like to order?',
        _checkbox(['color 1', 'color 2', 'color 3', 'color 4'])),
    _q('4', 'Product options', _paragraph),
    Item(
      itemId: 'ti1',
      title: 'Contact info',
      content: const TextItemContent(),
    ),
    _q('5', 'Your name', _text, required: true),
    _q('6', 'Phone number', _text, required: true),
    _q('7', 'E-mail', _text),
    _q('8', 'Preferred contact method',
        _checkbox(['Phone', 'Email']), required: true),
    _q('9', 'Questions and comments', _paragraph),
  ],
);

final _jobApplication = FormTemplate(
  title: 'Job application form',
  category: 'Work',
  imagePath: 'assets/template_image/job_application.png',
  icon: CupertinoIcons.person_crop_rectangle,
  items: [
    _q('1', 'Name', _text, required: true),
    _q('2', 'Email', _text, required: true),
    _q('3', 'Phone number', _text, required: true),
    _q('4', 'Which position(s) are you interested in?',
        _checkbox(['Position 1', 'Position 2', 'Position 3']), required: true),
    _q('5', 'Submit your cover letter or resume', _paragraph),
  ],
);

final _timeOffRequest = FormTemplate(
  title: 'Time off request',
  category: 'Work',
  imagePath: 'assets/template_image/time_off_request.png',
  icon: CupertinoIcons.calendar_badge_minus,
  items: [
    _q('1', 'Name', _text, required: true),
    _q('2', 'Leave date(s)', _text, required: true),
    _q('3', 'AM/PM/All day', _radio(['AM', 'PM', 'Full day']), required: true),
    Item(
      itemId: 'ti1',
      title: 'Type of leave',
      content: const TextItemContent(),
    ),
    _q('4', 'Type of leave',
        ChoiceQuestion(
          type: ChoiceType.radio,
          options: [
            ChoiceOption(value: 'Sick leave (Illness or Injury)'),
            ChoiceOption(value: 'Bereavement leave (Immediate Family)'),
            ChoiceOption(value: 'Bereavement leave (Other)'),
            ChoiceOption(value: 'Personal leave'),
            ChoiceOption(value: 'Jury duty or legal leave'),
            ChoiceOption(value: 'Emergency leave'),
            ChoiceOption(value: 'Temporary leave'),
            ChoiceOption(value: 'Leave without pay'),
            ChoiceOption(value: '', isOther: true),
          ],
        ),
        required: true),
    _q('5', 'Reason for leave', _paragraph),
  ],
);

// ── Personal ──────────────────────────────────────────────────────────────────

final _rsvp = FormTemplate(
  title: 'Event RSVP',
  category: 'Personal',
  imagePath: 'assets/template_image/rsvp.png',
  icon: CupertinoIcons.checkmark_seal,
  items: [
    _q('1', 'Can you attend?', _radio(['Yes, I\'ll be there', 'Sorry, can\'t make it']),
        required: true),
    _q('2', 'What are the names of people attending?', _paragraph),
    _q('3', 'How did you hear about this event?',
        _radio(['Website', 'Friend', 'Newsletter', 'Advertisement'])),
    _q('4', 'Comments and/or questions', _paragraph),
  ],
);

final _eventRegistration = FormTemplate(
  title: 'Event Registration',
  category: 'Personal',
  imagePath: 'assets/template_image/event_registration.png',
  icon: CupertinoIcons.calendar,
  items: [
    _q('1', 'Name', _text, required: true),
    _q('2', 'Email', _text, required: true),
    _q('3', 'Organization', _text, required: true),
    _q('4', 'What days will you attend?',
        _checkbox(['Day 1', 'Day 2', 'Day 3']), required: true),
    _q('5', 'Dietary restrictions',
        ChoiceQuestion(
          type: ChoiceType.radio,
          options: [
            ChoiceOption(value: 'None'),
            ChoiceOption(value: 'Vegetarian'),
            ChoiceOption(value: 'Vegan'),
            ChoiceOption(value: 'Kosher'),
            ChoiceOption(value: 'Gluten-free'),
            ChoiceOption(value: '', isOther: true),
          ],
        ),
        required: true),
    _q('6', 'I understand that I will have to pay \$\$ upon arrival',
        _checkbox(['Yes']), required: true),
  ],
);

final _eventFeedback = FormTemplate(
  title: 'Event Feedback',
  category: 'Personal',
  imagePath: 'assets/template_image/event_feedback.png',
  icon: CupertinoIcons.star,
  items: [
    _q('1', 'How satisfied were you with the event?',
        const ScaleQuestion(low: 1, high: 5, lowLabel: 'Not very', highLabel: 'Very much'),
        required: true),
    _q('2', 'How relevant and helpful do you think it was for your job?',
        const ScaleQuestion(low: 1, high: 5, lowLabel: 'Not very', highLabel: 'Very much'),
        required: true),
    _q('3', 'What were your key take aways from this event?', _text),
    Item(
      itemId: 'g1',
      title: 'How satisfied were you with the logistics?',
      content: QuestionGroupItemContent(
        questions: [
          Question(questionId: 'qg1r1', required: true, kind: const RowQuestion(title: 'Accommodation')),
          Question(questionId: 'qg1r2', required: true, kind: const RowQuestion(title: 'Welcome kit')),
          Question(questionId: 'qg1r3', required: true, kind: const RowQuestion(title: 'Communication')),
          Question(questionId: 'qg1r4', required: true, kind: const RowQuestion(title: 'Transportation')),
          Question(questionId: 'qg1r5', required: true, kind: const RowQuestion(title: 'Welcome activity')),
          Question(questionId: 'qg1r6', required: true, kind: const RowQuestion(title: 'Venue')),
          Question(questionId: 'qg1r7', required: true, kind: const RowQuestion(title: 'Activities')),
          Question(questionId: 'qg1r8', required: true, kind: const RowQuestion(title: 'Closing ceremony')),
        ],
        grid: Grid(
          columns: ChoiceQuestion(
            type: ChoiceType.radio,
            options: [
              ChoiceOption(value: '1'),
              ChoiceOption(value: '2'),
              ChoiceOption(value: '3'),
              ChoiceOption(value: '4'),
              ChoiceOption(value: '5'),
              ChoiceOption(value: 'N/A'),
            ],
          ),
        ),
      ),
    ),
    _q('4', 'Additional feedback on logistics', _text, required: true),
    Item(
      itemId: 'g2',
      title: 'Which sessions did you find most relevant?',
      content: QuestionGroupItemContent(
        questions: [
          Question(questionId: 'qg2r1', required: true, kind: const RowQuestion(title: 'Welcome activity')),
          Question(questionId: 'qg2r2', required: true, kind: const RowQuestion(title: 'Speaker #1')),
          Question(questionId: 'qg2r3', required: true, kind: const RowQuestion(title: 'Activity #1')),
          Question(questionId: 'qg2r4', required: true, kind: const RowQuestion(title: 'Speaker #2')),
          Question(questionId: 'qg2r5', required: true, kind: const RowQuestion(title: 'Activity #2')),
          Question(questionId: 'qg2r6', required: true, kind: const RowQuestion(title: 'Closing activity')),
        ],
        grid: Grid(
          columns: ChoiceQuestion(
            type: ChoiceType.radio,
            options: [
              ChoiceOption(value: 'Not relevant'),
              ChoiceOption(value: 'Relevant'),
              ChoiceOption(value: 'Very relevant'),
              ChoiceOption(value: 'Did not attend'),
            ],
          ),
        ),
      ),
    ),
    _q('5', 'How satisfied were you with the session content?',
        const ScaleQuestion(low: 1, high: 5, lowLabel: 'Poor', highLabel: 'Excellent'),
        required: true),
    _q('6', 'Any additional comments regarding the sessions or overall agenda?', _text),
    _q('7', 'Any overall feedback for the event?', _text),
    _q('8', 'Name (optional)', _text),
  ],
);

final _partyInvite = FormTemplate(
  title: 'Party Invite',
  category: 'Personal',
  imagePath: 'assets/template_image/party_invite.png',
  icon: CupertinoIcons.gift,
  items: [
    _q('1', 'What is your name?', _text),
    _q('2', 'Can you attend?',
        _radio(['Yes, I\'ll be there', 'Sorry, can\'t make it']),
        required: true),
    _q('3', 'How many of you are attending?', _text),
    Item(
      itemId: '4',
      title: 'What will you be bringing?',
      description: "Let us know what kind of dish(es) you'll be bringing",
      content: QuestionItemContent(
        question: Question(
          questionId: 'q4',
          kind: ChoiceQuestion(
            type: ChoiceType.checkbox,
            options: [
              ChoiceOption(value: 'Mains'),
              ChoiceOption(value: 'Salad'),
              ChoiceOption(value: 'Dessert'),
              ChoiceOption(value: 'Drinks'),
              ChoiceOption(value: 'Sides/Appetizers'),
              ChoiceOption(value: '', isOther: true),
            ],
          ),
        ),
      ),
    ),
    _q('5', 'Do you have any allergies or dietary restrictions?', _text),
    _q('6', 'What is your email address?', _text),
  ],
);

final _tshirtSignup = FormTemplate(
  title: 'T-Shirt Sign Up',
  category: 'Personal',
  imagePath: 'assets/template_image/tshirt_size.png',
  icon: CupertinoIcons.tag,
  items: [
    _q('1', 'Name', _text, required: true),
    _q('2', 'Shirt size', _radio(['XS', 'S', 'M', 'L', 'XL'])),
    Item(
      itemId: 'img1',
      title: 'T-Shirt Preview',
      content: ImageItemContent(
        image: FormImage(
          sourceUri:
              'https://lh7-rt.googleusercontent.com/formsz/AN7BsVADpMZ-JJ5UqkmHXIXyxdrvbiJ0IeQexMTgyExz8wC-UxO_JrZ1V7MtOOi77QJuRZgvdmU4ZkxYhVoo-ZchMlDkXmFzXyQh07wWrKYIJh4bFj-OEA5KV3_GqwdAruDLnU6Oo4ukcCzmlXlbO1gnvdfr447C2hI30Bwh=s2048?key=vQL4MrQ8tNixKDs5NZhxqQ',
        ),
      ),
    ),
    _q('3', 'Other thoughts or comments', _paragraph),
  ],
);

final _findATime = FormTemplate(
  title: 'Find a Time',
  category: 'Personal',
  imagePath: 'assets/template_image/find_a_time.png',
  icon: CupertinoIcons.clock,
  items: [
    Item(
      itemId: 'g1',
      title: 'What times are you available?',
      description: 'Please select all that apply',
      content: QuestionGroupItemContent(
        questions: [
          Question(questionId: 'qg1r1', kind: const RowQuestion(title: 'Monday')),
          Question(questionId: 'qg1r2', kind: const RowQuestion(title: 'Tuesday')),
          Question(questionId: 'qg1r3', kind: const RowQuestion(title: 'Wednesday')),
          Question(questionId: 'qg1r4', kind: const RowQuestion(title: 'Thursday')),
          Question(questionId: 'qg1r5', kind: const RowQuestion(title: 'Friday')),
        ],
        grid: Grid(
          columns: ChoiceQuestion(
            type: ChoiceType.checkbox,
            options: [
              ChoiceOption(value: 'Morning'),
              ChoiceOption(value: 'Midday'),
              ChoiceOption(value: 'Afternoon'),
              ChoiceOption(value: 'Evening'),
            ],
          ),
        ),
      ),
    ),
    _q('1', 'Items to discuss?', _paragraph),
    _q('2', 'Allergies or dietary restrictions?',
        ChoiceQuestion(
          type: ChoiceType.radio,
          options: [
            ChoiceOption(value: 'Vegetarian'),
            ChoiceOption(value: 'Vegan'),
            ChoiceOption(value: 'Kosher'),
            ChoiceOption(value: 'Halal'),
            ChoiceOption(value: 'Gluten-free'),
            ChoiceOption(value: 'None'),
            ChoiceOption(value: '', isOther: true),
          ],
        )),
    _q('3', 'Any other comments and/or questions?', _paragraph),
  ],
);

// ── Education ─────────────────────────────────────────────────────────────────

final _courseEvaluation = FormTemplate(
  title: 'Course evaluation',
  category: 'Education',
  imagePath: 'assets/template_image/course_evaluation.png',
  icon: CupertinoIcons.chart_bar_square,
  items: [
    _q('1', 'Class name', _text, required: true),
    _q('2', 'Instructor', _text, required: true),
    Item(
      itemId: 'g1',
      title: 'Level of effort',
      content: QuestionGroupItemContent(
        questions: [
          Question(questionId: 'qg1r1', kind: const RowQuestion(title: 'Level of effort put into the course')),
        ],
        grid: Grid(
          columns: ChoiceQuestion(
            type: ChoiceType.radio,
            options: [
              ChoiceOption(value: 'Poor'),
              ChoiceOption(value: 'Fair'),
              ChoiceOption(value: 'Satisfactory'),
              ChoiceOption(value: 'Very good'),
              ChoiceOption(value: 'Excellent'),
            ],
          ),
        ),
      ),
    ),
    Item(
      itemId: 'g2',
      title: 'Contribution to learning',
      content: QuestionGroupItemContent(
        questions: [
          Question(questionId: 'qg2r1', kind: const RowQuestion(title: 'Level of skill/knowledge at start of course')),
          Question(questionId: 'qg2r2', kind: const RowQuestion(title: 'Level of skill/knowledge gained')),
          Question(questionId: 'qg2r3', kind: const RowQuestion(title: 'Level of skill/knowledge at end of course')),
          Question(questionId: 'qg2r4', kind: const RowQuestion(title: 'Contribution of course to overall program')),
        ],
        grid: Grid(
          columns: ChoiceQuestion(
            type: ChoiceType.radio,
            options: [
              ChoiceOption(value: 'Poor'),
              ChoiceOption(value: 'Fair'),
              ChoiceOption(value: 'Satisfactory'),
              ChoiceOption(value: 'Very good'),
              ChoiceOption(value: 'Excellent'),
            ],
          ),
        ),
      ),
    ),
    Item(
      itemId: 'g3',
      title: 'Skill and responsiveness of the instructor',
      content: QuestionGroupItemContent(
        questions: [
          Question(questionId: 'qg3r1', kind: const RowQuestion(title: 'Instructor was knowledgeable about the subject')),
          Question(questionId: 'qg3r2', kind: const RowQuestion(title: 'Presentations were clear and organized')),
          Question(questionId: 'qg3r3', kind: const RowQuestion(title: 'Instructor stimulated interest in the subject')),
          Question(questionId: 'qg3r4', kind: const RowQuestion(title: 'Instructor effectively answered questions')),
          Question(questionId: 'qg3r5', kind: const RowQuestion(title: 'Instructor was available outside of class')),
          Question(questionId: 'qg3r6', kind: const RowQuestion(title: 'Grading was prompt and fair')),
        ],
        grid: Grid(
          columns: ChoiceQuestion(
            type: ChoiceType.radio,
            options: [
              ChoiceOption(value: 'Strongly disagree'),
              ChoiceOption(value: 'Disagree'),
              ChoiceOption(value: 'Neutral'),
              ChoiceOption(value: 'Agree'),
              ChoiceOption(value: 'Strongly agree'),
            ],
          ),
        ),
      ),
    ),
    Item(
      itemId: 'g4',
      title: 'Course content',
      content: QuestionGroupItemContent(
        questions: [
          Question(questionId: 'qg4r1', kind: const RowQuestion(title: 'Learning objectives were clear')),
          Question(questionId: 'qg4r2', kind: const RowQuestion(title: 'Course content was relevant to the objectives')),
          Question(questionId: 'qg4r3', kind: const RowQuestion(title: 'Course workload was appropriate')),
          Question(questionId: 'qg4r4', kind: const RowQuestion(title: 'Course organization was effective')),
        ],
        grid: Grid(
          columns: ChoiceQuestion(
            type: ChoiceType.radio,
            options: [
              ChoiceOption(value: 'Strongly disagree'),
              ChoiceOption(value: 'Disagree'),
              ChoiceOption(value: 'Neutral'),
              ChoiceOption(value: 'Agree'),
              ChoiceOption(value: 'Strongly agree'),
            ],
          ),
        ),
      ),
    ),
    _q('3', 'What aspects of this course were most useful or valuable?', _paragraph),
    _q('4', 'How would you improve this course?', _paragraph),
    _q('5', 'Why did you choose this course?',
        _radio(['Degree requirement', 'Time offered', 'Interest'])),
  ],
);

final _exitTicket = FormTemplate(
  title: 'Exit Ticket',
  category: 'Education',
  imagePath: 'assets/template_image/exit_ticket.png',
  icon: CupertinoIcons.lightbulb,
  items: [
    _q('1', 'Name', _text, required: true),
    _q('2', 'Email', _text),
    _q('3', "What's one important thing you learned in class today?", _paragraph),
    _q('4', "Did you feel prepared for today's lesson? Why or why not?", _paragraph),
    _q('5', "What would help make today's lesson more effective?", _paragraph),
  ],
);

final _blankQuiz = FormTemplate(
  title: 'Blank Quiz',
  category: 'Education',
  imagePath: 'assets/template_image/blank_quiz.png',
  icon: CupertinoIcons.question_circle,
  quizMode: true,
  items: [
    _q('1', 'Question 1', _radio(['Option A', 'Option B', 'Option C', 'Option D']), required: true),
  ],
);

final _assessment = FormTemplate(
  title: 'Assessment',
  category: 'Education',
  imagePath: 'assets/template_image/assessment.png',
  icon: CupertinoIcons.checkmark_circle,
  items: [
    _q('1', 'Name', _text, required: true),
    _q('2', 'Email', _text, required: true),
    Item(
      itemId: 'ti1',
      title: 'Quiz Questions',
      content: const TextItemContent(),
    ),
    _q('3', 'Your first question?',
        _radio(['Option 1', 'Correct answer', 'Option 3', 'Option 4']),
        required: true),
    _q('4', 'Your second question?',
        _checkbox(['Option 1', 'Correct answer 1', 'Option 3', 'Correct answer 2', 'Correct answer 3']),
        required: true),
    _q('5', 'Your third question?', _text, required: true),
    Item(
      itemId: 'ti2',
      title: 'Title',
      description:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque non risus ipsum. '
          'Nullam interdum semper erat, viverra tristique enim efficitur a. Praesent pretium diam enim. '
          'Sed orci magna, fermentum in aliquam tristique, dictum ac metus. Maecenas quis eros enim. '
          'Mauris ultrices orci mi, vitae tincidunt lorem efficitur a. Aenean pharetra, neque vel '
          'facilisis feugiat, eros nunc interdum lorem, vel finibus justo sapien eget ipsum.\n\n'
          'Aenean in dictum urna. Nullam pulvinar ex nec faucibus lobortis. Proin finibus nisi '
          'tristique, suscipit mi ut, maximus turpis. Pellentesque eu pharetra neque, vitae ullamcorper '
          'purus. Nullam mattis tellus magna, vitae suscipit dolor vulputate ac. Aenean imperdiet sapien '
          'lectus, id viverra neque fringilla nec.\n\n'
          'Praesent volutpat urna at nunc ullamcorper, id maximus felis suscipit. Mauris tincidunt, '
          'ipsum non aliquam malesuada, urna nisi varius dolor, sed imperdiet enim neque ut nulla.',
      content: const TextItemContent(),
    ),
    _q('6', 'Based on the text above, your fourth question.', _paragraph, required: true),
  ],
);

final _worksheet = FormTemplate(
  title: 'Worksheet title',
  category: 'Education',
  imagePath: 'assets/template_image/worksheet.png',
  icon: CupertinoIcons.doc_text,
  items: [
    _q('1', 'Name', _text, required: true),
    _q('2', 'Email', _text, required: true),
    _q('3', 'Question about this topic',
        _radio(['Option 1', 'Option 2', 'Option 3'])),
    Item(
      itemId: 'ti1',
      title: 'Title',
      description:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque non risus ipsum. '
          'Nullam interdum semper erat, viverra tristique enim efficitur a. Praesent pretium diam enim. '
          'Sed orci magna, fermentum in aliquam tristique, dictum ac metus. Maecenas quis eros enim. '
          'Mauris ultrices orci mi, vitae tincidunt lorem efficitur a. Aenean pharetra, neque vel '
          'facilisis feugiat, eros nunc interdum lorem, vel finibus justo sapien eget ipsum.\n\n'
          'Aenean in dictum urna. Nullam pulvinar ex nec faucibus lobortis. Proin finibus nisi '
          'tristique, suscipit mi ut, maximus turpis. Pellentesque eu pharetra neque, vitae ullamcorper '
          'purus. Nullam mattis tellus magna, vitae suscipit dolor vulputate ac. Aenean imperdiet sapien '
          'lectus, id viverra neque fringilla nec.\n\n'
          'Praesent volutpat urna at nunc ullamcorper, id maximus felis suscipit. Mauris tincidunt, '
          'ipsum non aliquam malesuada, urna nisi varius dolor, sed imperdiet enim neque ut nulla.',
      content: const TextItemContent(),
    ),
    _q('4', 'Question about this topic',
        _radio(['Option 1', 'Option 2', 'Option 3'])),
    _q('5', 'Question about this topic', _paragraph),
  ],
);

// ── Master list ───────────────────────────────────────────────────────────────

final List<FormTemplate> kFormTemplates = [
  // Work
  _contactInfo,
  _customerFeedback,
  _workRequest,
  _orderForm,
  _jobApplication,
  _timeOffRequest,
  // Personal
  _rsvp,
  _eventRegistration,
  _eventFeedback,
  _partyInvite,
  _tshirtSignup,
  _findATime,
  // Education
  _courseEvaluation,
  _exitTicket,
  _worksheet,
  _assessment,
];

final FormTemplate kBlankQuizTemplate = _blankQuiz;

final List<String> kTemplateCategories = ['Work', 'Personal', 'Education'];
