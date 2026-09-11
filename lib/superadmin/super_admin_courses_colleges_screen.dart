import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_common.dart';

class SuperAdminCoursesCollegesScreen extends StatefulWidget {
  const SuperAdminCoursesCollegesScreen({
    super.key,
  });

  @override
  State<SuperAdminCoursesCollegesScreen> createState() =>
      _SuperAdminCoursesCollegesScreenState();
}

class _SuperAdminCoursesCollegesScreenState
    extends State<SuperAdminCoursesCollegesScreen> {
  // ============================================================
  // ADD / EDIT ITEM
  // ============================================================

  Future<void> _showItemDialog({
    required String collection,
    required String field,
    String? id,
    String? initial,
  }) async {
    final controller = TextEditingController(
      text: initial ?? '',
    );

    final bool isCourse =
        collection == 'courses';

    final String itemName =
    isCourse ? 'Course' : 'College';

    final String collectionTitle =
    isCourse ? 'Courses' : 'Colleges';

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor:
          TraceColors.surface,
          insetPadding:
          const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
          ),
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth: 480,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.all(
                  22,
                ),
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================

                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment:
                          Alignment.center,
                          decoration:
                          BoxDecoration(
                            color:
                            TraceColors
                                .accentSoft,
                            borderRadius:
                            BorderRadius.circular(
                              12,
                            ),
                          ),
                          child:
                          Icon(
                            isCourse
                                ? Icons
                                .menu_book_rounded
                                : Icons
                                .account_balance_rounded,
                            color:
                            TraceColors
                                .accent,
                            size: 20,
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child:
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                id == null
                                    ? 'Add $itemName'
                                    : 'Edit $itemName',
                                style:
                                const TextStyle(
                                  color:
                                  TraceColors
                                      .textPrimary,
                                  fontSize:
                                  17,
                                  fontWeight:
                                  FontWeight
                                      .w800,
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                id == null
                                    ? 'Create a new $itemName for the academic structure.'
                                    : 'Update the $itemName information.',
                                style:
                                const TextStyle(
                                  color:
                                  TraceColors
                                      .textTertiary,
                                  fontSize:
                                  10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ==================================================
                    // FIELD
                    // ==================================================

                    TextFormField(
                      controller:
                      controller,
                      autofocus:
                      true,
                      textCapitalization:
                      TextCapitalization.words,
                      decoration:
                      _inputDecoration(
                        label:
                        '$itemName Name',
                        hint:
                        isCourse
                            ? 'e.g. BS Computer Science'
                            : 'e.g. College of Science',
                        icon:
                        isCourse
                            ? Icons
                            .menu_book_outlined
                            : Icons
                            .account_balance_outlined,
                      ),
                      validator:
                          (value) {
                        final text =
                            value
                                ?.trim() ??
                                '';

                        if (text.isEmpty) {
                          return 'Please enter a $itemName name.';
                        }

                        if (text.length <
                            2) {
                          return '$itemName name is too short.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // ==================================================
                    // ACTIONS
                    // ==================================================

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(
                              dialogContext,
                            );
                          },
                          child:
                          const Text(
                            'Cancel',
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        ElevatedButton.icon(
                          onPressed: () async {
                            if (!(formKey
                                .currentState
                                ?.validate() ??
                                false)) {
                              return;
                            }

                            final value =
                            controller
                                .text
                                .trim();

                            try {
                              final ref =
                              FirebaseFirestore
                                  .instance
                                  .collection(
                                collection,
                              );

                              if (id == null) {
                                await ref.add({
                                  field:
                                  value,
                                  'createdAt':
                                  FieldValue
                                      .serverTimestamp(),
                                  'updatedAt':
                                  FieldValue
                                      .serverTimestamp(),
                                });
                              } else {
                                await ref
                                    .doc(id)
                                    .update({
                                  field:
                                  value,
                                  'updatedAt':
                                  FieldValue
                                      .serverTimestamp(),
                                });
                              }

                              if (!dialogContext
                                  .mounted) {
                                return;
                              }

                              Navigator.pop(
                                dialogContext,
                              );

                              if (!mounted) {
                                return;
                              }

                              SuperAdminCommon
                                  .snack(
                                context,
                                id == null
                                    ? '$collectionTitle added successfully.'
                                    : '$collectionTitle updated successfully.',
                              );
                            } catch (e) {
                              if (!dialogContext
                                  .mounted) {
                                return;
                              }

                              SuperAdminCommon
                                  .snack(
                                dialogContext,
                                'Unable to save $itemName.',
                                error:
                                true,
                              );
                            }
                          },
                          icon:
                          const Icon(
                            Icons
                                .check_rounded,
                            size:
                            17,
                          ),
                          label:
                          Text(
                            id == null
                                ? 'Add $itemName'
                                : 'Save Changes',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    controller.dispose();
  }

  // ============================================================
  // DELETE ITEM
  // ============================================================

  Future<void> _deleteItem({
    required String collection,
    required String id,
    required String name,
  }) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final bool isCourse =
                collection == 'courses';

            final String item =
            isCourse
                ? 'course'
                : 'college';

            return AlertDialog(
              backgroundColor:
              TraceColors.surface,
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  18,
                ),
              ),
              title:
              const Text(
                'Delete Record',
                style:
                TextStyle(
                  color:
                  TraceColors
                      .textPrimary,
                  fontSize:
                  16,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
              content:
              Text(
                'Are you sure you want to delete "$name" from your $item list?',
                style:
                const TextStyle(
                  color:
                  TraceColors
                      .textSecondary,
                  fontSize:
                  12.5,
                  height:
                  1.4,
                ),
              ),
              actionsPadding:
              const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child:
                  const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    TraceColors
                        .danger,
                    foregroundColor:
                    Colors.white,
                    elevation: 0,
                  ),
                  icon:
                  const Icon(
                    Icons
                        .delete_outline_rounded,
                    size: 17,
                  ),
                  label:
                  const Text(
                    'Delete',
                  ),
                ),
              ],
            );
          },
        ) ??
            false;

    if (!confirmed) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(id)
          .delete();

      if (!mounted) {
        return;
      }

      SuperAdminCommon.snack(
        context,
        'Deleted successfully.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      SuperAdminCommon.snack(
        context,
        'Unable to delete record.',
        error: true,
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      TraceColors.canvas,
      body: SafeArea(
        child:
        SingleChildScrollView(
          physics:
          const BouncingScrollPhysics(),
          padding:
          const EdgeInsets.fromLTRB(
            18,
            22,
            18,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 1440,
              ),
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================

                  _PageHeader(
                    onAddCourse:
                        () {
                      _showItemDialog(
                        collection:
                        'courses',
                        field:
                        'courseName',
                      );
                    },
                    onAddCollege:
                        () {
                      _showItemDialog(
                        collection:
                        'colleges',
                        field:
                        'collegeName',
                      );
                    },
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  // ==================================================
                  // COLLECTIONS
                  // ==================================================

                  LayoutBuilder(
                    builder:
                        (
                        context,
                        constraints,
                        ) {
                      final bool mobile =
                          constraints
                              .maxWidth <
                              900;

                      final colleges =
                      _CollectionCard(
                        title:
                        'Colleges',
                        subtitle:
                        'Manage academic colleges and departments.',
                        icon:
                        Icons
                            .account_balance_rounded,
                        collection:
                        'colleges',
                        field:
                        'collegeName',
                        accent:
                        TraceColors
                            .success,

                        // IMPORTANT:
                        // These are now void callbacks.
                        onAdd:
                            () {
                          _showItemDialog(
                            collection:
                            'colleges',
                            field:
                            'collegeName',
                          );
                        },

                        onEdit:
                            (
                            id,
                            name,
                            ) {
                          _showItemDialog(
                            collection:
                            'colleges',
                            field:
                            'collegeName',
                            id:
                            id,
                            initial:
                            name,
                          );
                        },

                        onDelete:
                            (
                            id,
                            name,
                            ) {
                          _deleteItem(
                            collection:
                            'colleges',
                            id:
                            id,
                            name:
                            name,
                          );
                        },
                      );

                      final courses =
                      _CollectionCard(
                        title:
                        'Courses',
                        subtitle:
                        'Manage academic programs used by students.',
                        icon:
                        Icons
                            .menu_book_rounded,
                        collection:
                        'courses',
                        field:
                        'courseName',
                        accent:
                        TraceColors
                            .accent,

                        onAdd:
                            () {
                          _showItemDialog(
                            collection:
                            'courses',
                            field:
                            'courseName',
                          );
                        },

                        onEdit:
                            (
                            id,
                            name,
                            ) {
                          _showItemDialog(
                            collection:
                            'courses',
                            field:
                            'courseName',
                            id:
                            id,
                            initial:
                            name,
                          );
                        },

                        onDelete:
                            (
                            id,
                            name,
                            ) {
                          _deleteItem(
                            collection:
                            'courses',
                            id:
                            id,
                            name:
                            name,
                          );
                        },
                      );

                      if (mobile) {
                        return Column(
                          children: [
                            colleges,
                            const SizedBox(
                              height: 18,
                            ),
                            courses,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Expanded(
                            child:
                            colleges,
                          ),
                          const SizedBox(
                            width: 18,
                          ),
                          Expanded(
                            child:
                            courses,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText:
      label,
      hintText:
      hint,
      labelStyle:
      const TextStyle(
        color:
        TraceColors
            .textSecondary,
        fontSize:
        11.5,
      ),
      hintStyle:
      const TextStyle(
        color:
        TraceColors
            .textTertiary,
        fontSize:
        11.5,
      ),
      prefixIcon:
      Icon(
        icon,
        size:
        18,
        color:
        TraceColors
            .textTertiary,
      ),
      filled:
      true,
      fillColor:
      TraceColors.canvas,
      contentPadding:
      const EdgeInsets
          .symmetric(
        horizontal:
        14,
        vertical:
        13,
      ),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        borderSide:
        const BorderSide(
          color:
          TraceColors
              .border,
        ),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        borderSide:
        const BorderSide(
          color:
          TraceColors
              .border,
        ),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        borderSide:
        const BorderSide(
          color:
          TraceColors
              .accent,
          width:
          1.2,
        ),
      ),
      errorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        borderSide:
        const BorderSide(
          color:
          TraceColors
              .danger,
        ),
      ),
      focusedErrorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        borderSide:
        const BorderSide(
          color:
          TraceColors
              .danger,
          width:
          1.2,
        ),
      ),
    );
  }
}

// ================================================================
// PAGE HEADER
// ================================================================

class _PageHeader
    extends StatelessWidget {
  final VoidCallback onAddCourse;
  final VoidCallback onAddCollege;

  const _PageHeader({
    required this.onAddCourse,
    required this.onAddCollege,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder:
          (
          context,
          constraints,
          ) {
        final bool mobile =
            constraints.maxWidth <
                600;

        if (mobile) {
          return Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment:
                    Alignment.center,
                    decoration:
                    BoxDecoration(
                      color:
                      TraceColors
                          .accentSoft,
                      borderRadius:
                      BorderRadius
                          .circular(
                        13,
                      ),
                    ),
                    child:
                    const Icon(
                      Icons
                          .account_balance_rounded,
                      color:
                      TraceColors
                          .accent,
                      size: 21,
                    ),
                  ),

                  const SizedBox(
                    width: 13,
                  ),

                  const Expanded(
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          'Courses & Colleges',
                          style:
                          TextStyle(
                            color:
                            TraceColors
                                .textPrimary,
                            fontSize:
                            23,
                            fontWeight:
                            FontWeight
                                .w800,
                            letterSpacing:
                            -0.5,
                          ),
                        ),
                        SizedBox(
                          height: 4,
                        ),
                        Text(
                          'Manage the academic structure used by the system.',
                          maxLines:
                          2,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          TextStyle(
                            color:
                            TraceColors
                                .textSecondary,
                            fontSize:
                            11,
                            height:
                            1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 14,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                    ElevatedButton.icon(
                      onPressed:
                      onAddCollege,
                      icon:
                      const Icon(
                        Icons
                            .account_balance_outlined,
                        size:
                        16,
                      ),
                      label:
                      const Text(
                        'College',
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child:
                    OutlinedButton.icon(
                      onPressed:
                      onAddCourse,
                      icon:
                      const Icon(
                        Icons
                            .menu_book_outlined,
                        size:
                        16,
                      ),
                      label:
                      const Text(
                        'Course',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment:
              Alignment.center,
              decoration:
              BoxDecoration(
                color:
                TraceColors
                    .accentSoft,
                borderRadius:
                BorderRadius.circular(
                  13,
                ),
              ),
              child:
              const Icon(
                Icons
                    .account_balance_rounded,
                color:
                TraceColors.accent,
                size: 21,
              ),
            ),

            const SizedBox(
              width: 13,
            ),

            const Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    'Courses & Colleges',
                    style:
                    TextStyle(
                      color:
                      TraceColors
                          .textPrimary,
                      fontSize:
                      25,
                      fontWeight:
                      FontWeight
                          .w800,
                      letterSpacing:
                      -0.5,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Text(
                    'Manage the academic structure used by the attendance system.',
                    style:
                    TextStyle(
                      color:
                      TraceColors
                          .textSecondary,
                      fontSize:
                      11.5,
                      height:
                      1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            OutlinedButton.icon(
              onPressed:
              onAddCollege,
              icon:
              const Icon(
                Icons
                    .account_balance_outlined,
                size:
                17,
              ),
              label:
              const Text(
                'Add College',
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            ElevatedButton.icon(
              onPressed:
              onAddCourse,
              icon:
              const Icon(
                Icons
                    .add_rounded,
                size:
                17,
              ),
              label:
              const Text(
                'Add Course',
              ),
            ),
          ],
        );
      },
    );
  }
}

// ================================================================
// COLLECTION CARD
// ================================================================

class _CollectionCard
    extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String collection;
  final String field;
  final Color accent;

  final VoidCallback onAdd;

  // IMPORTANT:
  // These are VOID callbacks, not Future callbacks.
  final void Function(
      String id,
      String name,
      ) onEdit;

  final void Function(
      String id,
      String name,
      ) onDelete;

  const _CollectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.collection,
    required this.field,
    required this.accent,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CollectionCard> createState() =>
      _CollectionCardState();
}

class _CollectionCardState
    extends State<_CollectionCard> {
  final TextEditingController _search =
  TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
      BoxDecoration(
        color:
        TraceColors.surface,
        borderRadius:
        BorderRadius.circular(
          19,
        ),
        border:
        Border.all(
          color:
          TraceColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black
                .withValues(
              alpha:
              0.018,
            ),
            blurRadius:
            22,
            offset:
            const Offset(
              0,
              7,
            ),
          ),
        ],
      ),
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          18,
        ),
        child:
        Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            // ==================================================
            // CARD HEADER
            // ==================================================

            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment:
                  Alignment.center,
                  decoration:
                  BoxDecoration(
                    color:
                    widget.accent
                        .withValues(
                      alpha:
                      0.10,
                    ),
                    borderRadius:
                    BorderRadius
                        .circular(
                      12,
                    ),
                  ),
                  child:
                  Icon(
                    widget.icon,
                    color:
                    widget.accent,
                    size:
                    20,
                  ),
                ),

                const SizedBox(
                  width: 11,
                ),

                Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        widget.title,
                        style:
                        const TextStyle(
                          color:
                          TraceColors
                              .textPrimary,
                          fontSize:
                          14,
                          fontWeight:
                          FontWeight
                              .w800,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        widget.subtitle,
                        maxLines:
                        1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color:
                          TraceColors
                              .textTertiary,
                          fontSize:
                          9.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal:
                    9,
                    vertical:
                    7,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    widget.accent
                        .withValues(
                      alpha:
                      0.08,
                    ),
                    borderRadius:
                    BorderRadius
                        .circular(
                      8,
                    ),
                  ),
                  child:
                  Icon(
                    widget.icon,
                    color:
                    widget.accent,
                    size:
                    14,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // SEARCH
            // ==================================================

            TextField(
              controller:
              _search,
              onChanged:
                  (_) {
                setState(
                      () {},
                );
              },
              decoration:
              InputDecoration(
                isDense:
                true,
                hintText:
                'Search ${widget.title.toLowerCase()}...',
                hintStyle:
                const TextStyle(
                  color:
                  TraceColors
                      .textTertiary,
                  fontSize:
                  11.5,
                ),
                prefixIcon:
                const Icon(
                  Icons
                      .search_rounded,
                  size:
                  18,
                  color:
                  TraceColors
                      .textTertiary,
                ),
                suffixIcon:
                _search
                    .text
                    .isNotEmpty
                    ? IconButton(
                  onPressed:
                      () {
                    _search
                        .clear();

                    setState(
                          () {},
                    );
                  },
                  icon:
                  const Icon(
                    Icons
                        .close_rounded,
                    size:
                    17,
                    color:
                    TraceColors
                        .textTertiary,
                  ),
                )
                    : null,
                filled:
                true,
                fillColor:
                TraceColors
                    .canvas,
                contentPadding:
                const EdgeInsets
                    .symmetric(
                  horizontal:
                  12,
                  vertical:
                  12,
                ),
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    11,
                  ),
                  borderSide:
                  BorderSide.none,
                ),
                enabledBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    11,
                  ),
                  borderSide:
                  BorderSide.none,
                ),
                focusedBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    11,
                  ),
                  borderSide:
                  BorderSide(
                    color:
                    widget.accent,
                    width:
                    1.2,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            const Divider(
              height: 1,
              color:
              TraceColors.border,
            ),

            const SizedBox(
              height: 8,
            ),

            // ==================================================
            // FIRESTORE
            // ==================================================

            StreamBuilder<
                QuerySnapshot<
                    Map<String,
                        dynamic>>>(
              stream:
              FirebaseFirestore
                  .instance
                  .collection(
                widget.collection,
              )
                  .orderBy(
                widget.field,
              )
                  .limit(500)
                  .snapshots(),
              builder:
                  (
                  context,
                  snapshot,
                  ) {
                if (snapshot
                    .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const SizedBox(
                    height:
                    220,
                    child:
                    Center(
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                        color:
                        TraceColors
                            .accent,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SizedBox(
                    height:
                    220,
                    child:
                    SuperAdminCommon
                        .empty(
                      'Unable to load records.',
                      icon:
                      Icons
                          .error_outline_rounded,
                    ),
                  );
                }

                final docs =
                    snapshot.data
                        ?.docs ??
                        [];

                final query =
                _search.text
                    .trim()
                    .toLowerCase();

                final filtered =
                docs.where(
                      (doc) {
                    if (query
                        .isEmpty) {
                      return true;
                    }

                    final name =
                    SuperAdminCommon
                        .text(
                      doc.data(),
                      [
                        widget.field,
                      ],
                    );

                    return name
                        .toLowerCase()
                        .contains(
                      query,
                    );
                  },
                ).toList();

                // ==================================================
                // CONTENT
                // ==================================================

                return Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${filtered.length} ${widget.title.toLowerCase()}',
                          style:
                          const TextStyle(
                            color:
                            TraceColors
                                .textTertiary,
                            fontSize:
                            9.5,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),

                        const Spacer(),

                        TextButton.icon(
                          onPressed:
                          widget
                              .onAdd,
                          icon:
                          const Icon(
                            Icons
                                .add_rounded,
                            size:
                            15,
                          ),
                          label:
                          const Text(
                            'Add',
                          ),
                          style:
                          TextButton.styleFrom(
                            foregroundColor:
                            widget
                                .accent,
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal:
                              8,
                            ),
                            textStyle:
                            const TextStyle(
                              fontSize:
                              10,
                              fontWeight:
                              FontWeight
                                  .w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    if (filtered.isEmpty)
                      SizedBox(
                        height:
                        210,
                        child:
                        SuperAdminCommon
                            .empty(
                          query.isNotEmpty
                              ? 'No ${widget.title.toLowerCase()} match your search.'
                              : 'No ${widget.title.toLowerCase()} found.',
                          icon:
                          widget.icon,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap:
                        true,
                        physics:
                        const NeverScrollableScrollPhysics(),
                        itemCount:
                        filtered.length,
                        separatorBuilder:
                            (
                            _,
                            __,
                            ) {
                          return const Divider(
                            height:
                            1,
                            color:
                            TraceColors
                                .border,
                          );
                        },
                        itemBuilder:
                            (
                            context,
                            index,
                            ) {
                          final doc =
                          filtered[
                          index];

                          final name =
                          SuperAdminCommon
                              .text(
                            doc.data(),
                            [
                              widget.field,
                            ],
                            fallback:
                            'Unnamed',
                          );

                          return _CollectionListItem(
                            index:
                            index,
                            name:
                            name,
                            icon:
                            widget.icon,
                            accent:
                            widget.accent,
                            onEdit:
                                () {
                              widget
                                  .onEdit(
                                doc.id,
                                name,
                              );
                            },
                            onDelete:
                                () {
                              widget
                                  .onDelete(
                                doc.id,
                                name,
                              );
                            },
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// COLLECTION LIST ITEM
// ================================================================

class _CollectionListItem
    extends StatelessWidget {
  final int index;
  final String name;
  final IconData icon;
  final Color accent;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CollectionListItem({
    required this.index,
    required this.name,
    required this.icon,
    required this.accent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child:
      Row(
        children: [
          // ------------------------------------------------------
          // INDEX
          // ------------------------------------------------------

          Container(
            width: 32,
            height: 32,
            alignment:
            Alignment.center,
            decoration:
            BoxDecoration(
              color:
              accent.withValues(
                alpha:
                0.08,
              ),
              borderRadius:
              BorderRadius.circular(
                9,
              ),
            ),
            child:
            Text(
              '${index + 1}',
              style:
              TextStyle(
                color:
                accent,
                fontSize:
                9.5,
                fontWeight:
                FontWeight
                    .w800,
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          // ------------------------------------------------------
          // ICON
          // ------------------------------------------------------

          Container(
            width: 29,
            height: 29,
            alignment:
            Alignment.center,
            decoration:
            BoxDecoration(
              color:
              TraceColors.canvas,
              borderRadius:
              BorderRadius.circular(
                8,
              ),
              border:
              Border.all(
                color:
                TraceColors.border,
              ),
            ),
            child:
            Icon(
              icon,
              size:
              14,
              color:
              TraceColors
                  .textTertiary,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          // ------------------------------------------------------
          // NAME
          // ------------------------------------------------------

          Expanded(
            child:
            Text(
              name,
              maxLines:
              2,
              overflow:
              TextOverflow.ellipsis,
              style:
              const TextStyle(
                color:
                TraceColors
                    .textPrimary,
                fontSize:
                11.5,
                fontWeight:
                FontWeight
                    .w700,
                height:
                1.25,
              ),
            ),
          ),

          const SizedBox(
            width: 5,
          ),

          // ------------------------------------------------------
          // EDIT
          // ------------------------------------------------------

          IconButton(
            tooltip:
            'Edit',
            visualDensity:
            VisualDensity
                .compact,
            onPressed:
            onEdit,
            icon:
            const Icon(
              Icons
                  .edit_outlined,
              color:
              TraceColors
                  .textSecondary,
              size:
              17,
            ),
          ),

          // ------------------------------------------------------
          // DELETE
          // ------------------------------------------------------

          IconButton(
            tooltip:
            'Delete',
            visualDensity:
            VisualDensity
                .compact,
            onPressed:
            onDelete,
            icon:
            const Icon(
              Icons
                  .delete_outline_rounded,
              color:
              TraceColors.danger,
              size:
              17,
            ),
          ),
        ],
      ),
    );
  }
}