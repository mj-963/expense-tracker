import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NewTransactionScreen extends StatefulWidget {
  const NewTransactionScreen({super.key});

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _currentType = 'expense';
  String _txId = '';
  double _amount = 0.0;
  final TextEditingController _amountController = TextEditingController(
    text: '0',
  );

  bool _isSaving = false;

  // Category selections
  Map<String, String?> expenseSelections = {"Food & Drink": "Breakfast"};

  // Payment method selections
  Map<String, String?> paymentSelections = {"Asset": "Cash"};

  // income selections
  Map<String, String?> incomeSelections = {"Salary": "Salary"};

  // Transfer selections
  Map<String, String?> fromWalletSelections = {"Asset": "Cash"};
  Map<String, String?> toWalletSelections = {"Asset": "Credit Card"};

  DateTime _selectedDate = DateTime.now();
  String _recurrence = 'None';
  String _note = '';

  final _auth = FirebaseAuth.instance;

  final Map<String, List<String>> categories = {
    "Food & Drink": ["Breakfast", "Lunch", "Dinner", "Coffee"],
    "Shopping": ["Clothes", "Groceries", "Online", "Gifts"],
    "Transport": ["Bus", "Taxi", "Train", "Flight"],
    "Housing": ["Rent", "Mortgage", "Bills"],
    "Entertainment": ["Movies", "Concert", "Games"],
  };

  final Map<String, List<String>> incomeCategories = {
    "Salary": ["Salary"],
    "Investment": ["Dividends", "Interests"],
    "Allowance": ["Pocket Money", "Bonus"],
    "Gifts": ["Birthday", "Wedding", "Others"],
  };

  final Map<String, List<String>> paymentMethods = {
    "Asset": ["Cash", "Debit Card", "Paypal"],
    "Liability": ["Credit Card", "Loan Account"],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _currentType = 'expense';
            break;
          case 1:
            _currentType = 'income';
            break;
          case 2:
            _currentType = 'transfer';
            break;
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('transaction')) {
      final TransactionModel tx = args['transaction'];
      // Populate your fields with data from 'tx'
      setState(() {
        _amount = tx.amount;
        _amountController.text = tx.amount.toString();
        _selectedDate = tx.date;
        _recurrence = tx.recurrence;
        _note = tx.note;
        // For category & payment method, you might split the stored string if needed.
        _currentType = tx.type;
        switch (_currentType) {
          case 'expense':
            expenseSelections.clear();
            final parts = tx.category.split(' > ');
            expenseSelections[parts[0]] = parts[1];
            break;
          case 'income':
            incomeSelections.clear();
            final parts = tx.category.split(' > ');
            incomeSelections[parts[0]] = parts[1];
            break;
          case 'transfer':
            fromWalletSelections.clear();
            toWalletSelections.clear();
            final parts = tx.category.split(' > ');
            fromWalletSelections[parts[0]] = parts[1];
            final parts2 = tx.paymentMethod.split(' > ');
            toWalletSelections[parts2[0]] = parts2[1];
            break;
        }
      });

      // Update the tab controller index based on the transaction type
      switch (_currentType) {
        case 'expense':
          _tabController.index = 0;
          break;
        case 'income':
          _tabController.index = 1;
          break;
        case 'transfer':
          _tabController.index = 2;
          break;
      }

      // Store the transaction ID for updating
      _txId = tx.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3D0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "New Transaction",
          style: TextStyle(color: Colors.black, fontSize: 20),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFFFFF3D0),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.black,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: "Expense"),
                Tab(text: "Income"),
                Tab(text: "Transfer"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,

        children: [
          _buildTransactionForm(isExpense: true),
          _buildTransactionForm(isExpense: false),
          _buildTransferForm(),
        ],
      ),
      bottomSheet: _buildActionButtons(),
    );
  }

  Widget _buildTransactionForm({required bool isExpense}) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildAmountInput(),
          _buildCategorySelector(),
          _buildPaymentMethodSelector(),
          _buildDateSelector(),
          _buildRecurrenceSelector(),
          _buildNoteInput(),
          SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTransferForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildAmountInput(),
          _buildWalletSelector(isFrom: true),
          _buildWalletSelector(isFrom: false),
          _buildDateSelector(),
          _buildRecurrenceSelector(),
          _buildNoteInput(),
          SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "₦",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              onChanged: (val) {
                setState(() {
                  _amount = double.tryParse(val) ?? 0.0;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    if (_currentType == 'transfer') return const SizedBox.shrink();

    final mainCategory =
        _currentType == 'expense'
            ? expenseSelections.keys.first
            : incomeSelections.keys.first;

    final subCategory =
        _currentType == 'expense'
            ? expenseSelections[mainCategory]
            : incomeSelections[mainCategory];

    return _buildSelectorTile(
      icon: Icon(
        _currentType == 'expense' ? Icons.category : Icons.attach_money,
        color: Colors.orange,
      ),
      title: "Category",
      value: "$mainCategory > $subCategory",
      onTap:
          () => _showCategoryPicker(
            "Category",
            _currentType == 'expense' ? categories : incomeCategories,
            _currentType == 'expense' ? expenseSelections : incomeSelections,
          ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    if (_currentType == 'transfer') return const SizedBox.shrink();

    final mainMethod = paymentSelections.keys.first;
    final subMethod = paymentSelections[mainMethod];

    return _buildSelectorTile(
      icon: const Icon(Icons.account_balance_wallet, color: Colors.green),
      title: "Payment Method",
      value: "$mainMethod > $subMethod",
      onTap:
          () => _showCategoryPicker(
            "Payment Method",
            paymentMethods,
            paymentSelections,
          ),
    );
  }

  Widget _buildWalletSelector({required bool isFrom}) {
    final selections = isFrom ? fromWalletSelections : toWalletSelections;
    final mainWallet = selections.keys.first;
    final subWallet = selections[mainWallet];

    return _buildSelectorTile(
      icon: Icon(
        isFrom ? Icons.account_balance_wallet : Icons.credit_card,
        color: Colors.green,
      ),
      title: isFrom ? "From Wallet" : "To Wallet",
      value: "$mainWallet > $subWallet",
      onTap:
          () => _showCategoryPicker(
            isFrom ? "From Wallet" : "To Wallet",
            paymentMethods,
            selections,
          ),
    );
  }

  Widget _buildDateSelector() {
    return _buildSelectorTile(
      icon: const Icon(Icons.calendar_today, color: Color(0xFFFFE082)),
      title: "Date",
      value: _formatDate(_selectedDate),
      onTap: _pickDate,
    );
  }

  Widget _buildRecurrenceSelector() {
    return _buildSelectorTile(
      icon: const Icon(Icons.repeat, color: Color(0xFFFFE082)),
      title: "Recurrence",
      value: _recurrence,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [const SizedBox(width: 8), const Icon(Icons.chevron_right)],
      ),
      onTap: _showRecurrencePicker,
    );
  }

  Widget _buildNoteInput() {
    return _buildSelectorTile(
      icon: const Icon(Icons.note, color: Colors.grey),
      title: "Note",
      value: _note.isEmpty ? "Click to fill in the remarks" : _note,
      trailing: const Icon(Icons.camera_alt),
      onTap: () async {
        final note = await _showNoteInputDialog() ?? '';
        setState(() {
          _note = note;
        });
      },
    );
  }

  /// Recurrence popup dialog
  void _showRecurrencePicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                // Title
                Container(
                  height: 50,

                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(255),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "Recurrence",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // list of recurrence options
                Expanded(
                  child: Container(
                    color: AppColors.primary.withAlpha(130),
                    padding: const EdgeInsets.all(8),
                    child: _buildRecurrenceOptions(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecurrenceOptions() {
    final options = [
      "None",
      "Every Day",
      "Every Week",
      "Weekdays",
      "Weekends",
      "Every 2 Weeks",
      "Every 4 Weeks",
      "Every Month",
      "Every 2 Months",
      "Every 6 Months",
      "Every Year",
    ];
    return ListView.builder(
      itemCount: options.length,
      itemBuilder: (ctx, i) {
        final option = options[i];
        final isSelected = (option == _recurrence);
        return ListTile(
          title: Text(option),
          trailing:
              isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
          onTap: () {
            setState(() => _recurrence = option);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  /// Date picker with app color
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary, // header background color
              onPrimary: Colors.black, // header text color
              onSurface: Colors.black, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Note input
  Future<String?> _showNoteInputDialog() async {
    final controller = TextEditingController(text: _note);

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: const Text(
            'Note',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            style: const TextStyle(color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'Enter your remarks',
              hintStyle: const TextStyle(color: AppColors.textLight),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: AppColors.secondary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(
                  color: AppColors.secondary,
                  width: 2,
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: AppColors.expenseRed),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text(
                'SAVE',
                style: TextStyle(color: AppColors.incomeGreen),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectorTile({
    required Widget icon,
    required String title,
    required String value,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          leading: icon,
          title: Text(title, style: const TextStyle(color: Colors.grey)),
          subtitle: Text(value, style: const TextStyle(fontSize: 16)),
          trailing: trailing ?? const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.grey),
              ),
              onPressed: () {},
              child: const Text(
                "CONTINUE",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed:
                  () => _saveTransaction(id: _txId, isUpdate: _txId.isNotEmpty),
              child:
                  _isSaving
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("SAVE"),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  //  PICKERS / DIALOGS
  // ----------------------------------------------------------------

  /// Category picker (2-column style):
  /// Left column = main categories, Right column = subcategories
  void _showCategoryPicker(
    String title,
    Map<String, List<String>> map,
    Map<String, String?> currentselection,
  ) async {
    final category = await showDialog(
      context: context,

      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, stState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(vertical: 24, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    //header
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(255),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),

                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    //body
                    Expanded(
                      child: Row(
                        children: [
                          // Left column: main categories
                          Expanded(
                            flex: 1,
                            child: Container(
                              color: Colors.white70,

                              child: ListView(
                                children:
                                    map.keys.map((mainCat) {
                                      return ListTile(
                                        selected: currentselection.containsKey(
                                          mainCat,
                                        ),
                                        selectedTileColor: AppColors.dialogBg,
                                        selectedColor: AppColors.secondary,
                                        title: Text(
                                          mainCat,
                                          // style: TextStyle(
                                          //   color: AppColors.textDark,
                                          // ),
                                        ),
                                        onTap: () {
                                          stState(() {
                                            // Clear other selections when selecting a new main category
                                            currentselection.clear();
                                            currentselection[mainCat] = null;
                                          });
                                        },
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                          // Right column: sub categories
                          Expanded(
                            flex: 2,
                            child: Container(
                              color: AppColors.dialogBg,
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount:
                                          expenseSelections.isEmpty
                                              ? 0
                                              : map[currentselection.keys.first]
                                                      ?.length ??
                                                  0,
                                      itemBuilder: (ctx, i) {
                                        if (currentselection.isEmpty) {
                                          return SizedBox();
                                        }

                                        final mainCat =
                                            currentselection.keys.first;
                                        final subCat = map[mainCat]![i];
                                        final isSelected =
                                            currentselection[mainCat] == subCat;

                                        return ListTile(
                                          title: Text(subCat),
                                          trailing:
                                              isSelected
                                                  ? Icon(
                                                    Icons.check,
                                                    color: AppColors.secondary,
                                                  )
                                                  : null,
                                          onTap: () {
                                            // Return both category and subcategory
                                            Navigator.pop(context, {
                                              'mainCategory': mainCat,
                                              'subCategory': subCat,
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: TextButton(
                                      onPressed: () {
                                        // Add new subcategory logic
                                      },
                                      child: const Text(
                                        "+ ADD NEW",
                                        style: TextStyle(
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (category != null) {
      final mainCat = category['mainCategory'];
      final subCat = category['subCategory'];
      if (subCat != null) {
        switch (title) {
          case 'Category':
            setState(() {
              if (_currentType == 'expense') {
                expenseSelections.clear();
                expenseSelections[mainCat] = subCat;
              } else {
                incomeSelections.clear();
                incomeSelections[mainCat] = subCat;
              }
            });
            return;
          case 'Payment Method':
            setState(() {
              paymentSelections.clear();
              paymentSelections[mainCat] = subCat;
            });
            return;
          case 'From Wallet':
            setState(() {
              fromWalletSelections.clear();
              fromWalletSelections[mainCat] = subCat;
            });
            return;
          case 'To Wallet':
            setState(() {
              toWalletSelections.clear();
              toWalletSelections[mainCat] = subCat;
            });
            return;
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    final weekDay =
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    return "$weekDay. ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Future<void> _saveTransaction({String id = '', bool isUpdate = false}) async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount.")),
      );
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No user is logged in.")));
      return;
    }

    setState(() => _isSaving = true);

    // If not transfer, we store category + paymentMethod
    // If transfer, we store fromWallet -> toWallet in some way
    String category = '';
    String paymentMethod = '';
    if (_currentType == 'transfer') {
      category =
          'From: ${fromWalletSelections.keys.first} > ${fromWalletSelections.values.first}';
      paymentMethod =
          'To: ${toWalletSelections.keys.first} > ${toWalletSelections.values.first}';
    } else {
      if (_currentType == 'expense') {
        category =
            '${expenseSelections.keys.first} > ${expenseSelections.values.first}';
      } else {
        category =
            '${incomeSelections.keys.first} > ${incomeSelections.values.first}';
      }
      paymentMethod =
          '${paymentSelections.keys.first} > ${paymentSelections.values.first}';
    }

    final tx = TransactionModel(
      id: id.isNotEmpty ? id : DateTime.now().toString(),
      type: _currentType, // expense | income | transfer
      category: category,
      paymentMethod: paymentMethod,
      date: _selectedDate,
      recurrence: _recurrence,
      note: _note,
      amount: _amount,
    );

    try {
      if (isUpdate) {
        await updateTransaction(id, tx.toMap());
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .add(tx.toMap());
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Transaction saved.")));
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving transaction: $e")));
      }
    }
  }

  Future<void> updateTransaction(
    String transactionId,
    Map<String, dynamic> updatedData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // No user is logged in;
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transactionId)
          .update(updatedData);
    } catch (e) {
      rethrow;
    }
  }
}
