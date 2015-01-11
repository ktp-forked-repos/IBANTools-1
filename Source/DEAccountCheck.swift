/**
 * Copyright (c) 2014, 2015, Mike Lischke. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

import Foundation

@objc(DEAccountCheck)
internal class DEAccountCheck : AccountCheck {

  // Enumeration to describe the handling of the 3 computation result values (0, 1, anything else).
  private enum ResultMapping: Int16 {
    case DontMap = -1           // Means: don't do any special handling with that value. Not used it for the default case.
    case MapToZero = 0
    case MapToOne = 1
    case MapToSpecial = 99
    case ReturnSum
    case ReturnRemainder
    case ReturnDifference       // modulus - remainder
    case ReturnDiff2HalveDecade // Difference of the sum to the next halve decade (e.g. 25, 30, 35, 40 etc.)
    case ReturnDivByModulus     // sum / modulus
  }

  private struct Static {
    // Details for each used method.
    // In some cases the range is not continuous, which require a special slice construction then.
    typealias MethodParameters = (
      modulus: UInt16,
      weights: [UInt16],
      indices: (start: Int, stop: Int, check: Int)
    );
    static var methodParameters: [String: MethodParameters] = [:];

    static var m10hTransformationTable: [[UInt16]] = [
      [0, 1, 5, 9, 3, 7, 4, 8, 2, 6],
      [0, 1, 7, 6, 9, 8, 3, 2, 5, 4],
      [0, 1, 8, 4, 6, 2, 9, 5, 7, 3],
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    ];
  }

  override class func initialize() {
    super.initialize();

    Static.methodParameters["00"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["01"] = (10, [3, 7, 1, 3, 7, 1, 3, 7, 1], (0, 8, 9));
    Static.methodParameters["02"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 2], (0, 8, 9));
    Static.methodParameters["03"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["04"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["05"] = (10, [7, 3, 1, 7, 3, 1, 7, 3, 1], (0, 8, 9));
    Static.methodParameters["06"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["07"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 10], (0, 8, 9));
    Static.methodParameters["08"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["10"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 10], (0, 8, 9));
    Static.methodParameters["11"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 10], (0, 8, 9));
    Static.methodParameters["13"] = (10, [2, 1, 2, 1, 2, 1], (1, 6, 7));
    Static.methodParameters["13b"] = (10, [2, 1, 2, 1, 2, 1], (3, 8, 9));
    Static.methodParameters["14"] = (11, [2, 3, 4, 5, 6, 7], (0, 8, 9));
    Static.methodParameters["15"] = (11, [2, 3, 4, 5], (0, 8, 9));
    Static.methodParameters["16"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["17"] = (11, [1, 2, 1, 2, 1, 2], (1, 6, 9));
    Static.methodParameters["18"] = (10, [3, 9, 7, 1, 3, 9, 7, 1, 3], (0, 8, 9));
    Static.methodParameters["19"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 1], (0, 8, 9));
    Static.methodParameters["20"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 3], (0, 8, 9));
    Static.methodParameters["21"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["22"] = (10, [3, 1, 3, 1, 3, 1, 3, 1, 3], (0, 8, 9));
    Static.methodParameters["23"] = (11, [2, 3, 4, 5, 6, 7], (0, 5, 6));
    Static.methodParameters["24"] = (11, [1, 2, 3, 1, 2, 3, 1, 2, 3], (0, 8, 9));
    Static.methodParameters["25"] = (11, [2, 3, 4, 5, 6, 7, 8, 9], (0, 8, 9));
    Static.methodParameters["26"] = (11, [2, 3, 4, 5, 6, 7, 2], (0, 6, 7));
    Static.methodParameters["26b"] = (11, [2, 3, 4, 5, 6, 7, 2], (2, 8, 9));
    Static.methodParameters["27"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["28"] = (11, [2, 3, 4, 5, 6, 7, 8], (0, 6, 7));
    Static.methodParameters["29"] = (10, [], (0, 8, 9));
    Static.methodParameters["30"] = (10, [2, 0, 0, 0, 0, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["31"] = (11, [9, 8, 7, 6, 5, 4, 3, 2, 1], (0, 8, 9));
    Static.methodParameters["32"] = (11, [2, 3, 4, 5, 6, 7], (3, 8, 9));
    Static.methodParameters["33"] = (11, [2, 3, 4, 5, 6], (4, 8, 9));
    Static.methodParameters["34"] = (11, [2, 4, 8, 5, 10, 9, 7], (0, 6, 7));
    Static.methodParameters["35"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 10], (0, 8, 9));
    Static.methodParameters["36"] = (11, [2, 4, 8, 5], (5, 8, 9));
    Static.methodParameters["37"] = (11, [2, 4, 8, 5, 10], (4, 8, 9));
    Static.methodParameters["38"] = (11, [2, 4, 8, 5, 10, 9], (3, 8, 9));
    Static.methodParameters["39"] = (11, [2, 4, 8, 5, 10, 9, 7], (2, 8, 9));
    Static.methodParameters["40"] = (11, [2, 4, 8, 5, 10, 9, 7, 3, 6], (0, 8, 9));
    Static.methodParameters["41"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["42"] = (11, [2, 3, 4, 5, 6, 7, 8, 9], (1, 8, 9));
    Static.methodParameters["43"] = (10, [1, 2, 3, 4, 5, 6, 7, 8, 9], (0, 8, 9));
    Static.methodParameters["44"] = (11, [2, 4, 8, 5, 10, 0, 0, 0, 0], (4, 8, 9));
    Static.methodParameters["45"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["46"] = (11, [2, 3, 4, 5, 6], (2, 6, 7));
    Static.methodParameters["47"] = (11, [2, 3, 4, 5, 6], (3, 7, 8));
    Static.methodParameters["48"] = (11, [2, 3, 4, 5, 6, 7], (2, 7, 8));
    Static.methodParameters["49"] = (0, [], (0, 8, 9));
    Static.methodParameters["50"] = (11, [2, 3, 4, 5, 6, 7], (0, 5, 6));
    Static.methodParameters["50b"] = (11, [2, 3, 4, 5, 6, 7], (3, 8, 9));
    Static.methodParameters["51"] = (0, [], (0, 8, 9));
    Static.methodParameters["51a"] = (11, [2, 3, 4, 5, 6, 7], (3, 8, 9));
    Static.methodParameters["51b"] = (11, [2, 3, 4, 5, 6], (4, 8, 9));
    Static.methodParameters["51c"] = (10, [2, 1, 2, 1, 2, 1], (3, 8, 9));
    Static.methodParameters["51d"] = (7, [2, 3, 4, 5, 6], (4, 8, 9));
    Static.methodParameters["51e"] = (11, [2, 3, 4, 5, 6, 7, 8], (2, 8, 9));
    Static.methodParameters["51f"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 10], (0, 8, 9));
    Static.methodParameters["52"] = (11, [2, 4, 8, 5, 10, 9, 7, 3, 6, 1, 2, 4], (0, 8, 9));
    Static.methodParameters["53"] = (11, [2, 4, 8, 5, 10, 9, 7, 3, 6, 1, 2, 4], (0, 8, 9));
    Static.methodParameters["54"] = (11, [2, 3, 4, 5, 6, 7, 2], (0, 8, 9));
    Static.methodParameters["55"] = (11, [2, 3, 4, 5, 6, 7, 8, 7, 8], (0, 8, 9));
    Static.methodParameters["56"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["57"] = (10, [1, 2, 1, 2, 1, 2, 1, 2, 1], (0, 8, 9));
    Static.methodParameters["58"] = (11, [2, 3, 4, 5, 6, 0, 0, 0, 0], (4, 8, 9));
    Static.methodParameters["59"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["60"] = (10, [2, 1, 2, 1, 2, 1, 2], (2, 8, 9));
    Static.methodParameters["61"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 6, 7));
    Static.methodParameters["62"] = (10, [2, 1, 2, 1, 2], (2, 6, 7));
    Static.methodParameters["63"] = (10, [2, 1, 2, 1, 2, 1], (1, 6, 7));
    Static.methodParameters["63a"] = (10, [2, 1, 2, 1, 2, 1], (3, 8, 9));
    Static.methodParameters["64"] = (11, [9, 10, 5, 8, 4, 2], (0, 5, 6));
    Static.methodParameters["65"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 6, 7));
    Static.methodParameters["66"] = (11, [2, 3, 4, 5, 6, 0, 0, 7], (1, 8, 9));
    Static.methodParameters["67"] = (10, [2, 1, 2, 1, 2, 1, 2], (0, 6, 7));
    Static.methodParameters["68"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (3, 8, 9));
    Static.methodParameters["69"] = (11, [2, 3, 4, 5, 6, 7, 8], (0, 6, 7));
    Static.methodParameters["69b"] = (11, [], (0, 8, 9));
    Static.methodParameters["70"] = (11, [2, 3, 4, 5, 6, 7], (0, 8, 9));
    Static.methodParameters["71"] = (11, [6, 5, 4, 3, 2, 1], (1, 6, 9));
    Static.methodParameters["72"] = (10, [2, 1, 2, 1, 2, 1], (3, 8, 9));
    Static.methodParameters["73"] = (0, [], (0, 8, 9));
    Static.methodParameters["73a"] = (10, [2, 1, 2, 1, 2, 1], (3, 8, 9));
    Static.methodParameters["73b"] = (10, [2, 1, 2, 1, 2], (4, 8, 9));
    Static.methodParameters["73c"] = (7, [2, 1, 2, 1, 2], (4, 8, 9));
    Static.methodParameters["74"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["75"] = (10, [2, 1, 2, 1, 2], (4, 8, 9));
    Static.methodParameters["76"] = (11, [2, 3, 4, 5, 6, 7, 8], (1, 6, 7));
    Static.methodParameters["76b"] = (11, [2, 3, 4, 5, 6, 7, 8], (3, 8, 9));
    Static.methodParameters["77"] = (11, [1, 2, 3, 4, 5], (5, 9, 9)); // No checksum.
    Static.methodParameters["77b"] = (11, [5, 4, 3, 4, 5], (5, 9, 9)); // No checksum.
    Static.methodParameters["78"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["79"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["79b"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 7, 8));
    Static.methodParameters["80"] = (10, [2, 1, 2, 1, 2], (4, 8, 9));
    Static.methodParameters["80b"] = (7, [2, 1, 2, 1, 2], (4, 8, 9));
    Static.methodParameters["81"] = (11, [2, 3, 4, 5, 6, 7], (0, 8, 9));
    Static.methodParameters["82"] = (11, [2, 3, 4, 5, 6], (4, 8, 9));
    Static.methodParameters["83"] = (0, [], (0, 8, 9));
    Static.methodParameters["83a"] = (11, [2, 3, 4, 5, 6, 7], (0, 8, 9));
    Static.methodParameters["83b"] = (11, [2, 3, 4, 5, 6], (0, 8, 9));
    Static.methodParameters["83c"] = (7, [2, 3, 4, 5, 6], (0, 8, 9));
    Static.methodParameters["83d"] = (11, [2, 3, 4, 5, 6, 7, 8], (0, 8, 9));
    Static.methodParameters["84"] = (0, [], (0, 8, 9));
    Static.methodParameters["84a"] = (11, [2, 3, 4, 5, 6], (0, 8, 9));
    Static.methodParameters["84b"] = (7, [2, 3, 4, 5, 6], (0, 8, 9));
    Static.methodParameters["84c"] = (10, [2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["85"] = (0, [], (0, 8, 9));
    Static.methodParameters["85a"] = (11, [2, 3, 4, 5, 6, 7], (0, 8, 9));
    Static.methodParameters["85b"] = (11, [2, 3, 4, 5, 6], (0, 8, 9));
    Static.methodParameters["85c"] = (7, [2, 3, 4, 5, 6], (0, 8, 9));
    Static.methodParameters["85d"] = (11, [2, 3, 4, 5, 6, 7, 8], (0, 8, 9));
    Static.methodParameters["86"] = (0, [], (0, 8, 9));
    Static.methodParameters["86a"] = (10, [2, 1, 2, 1, 2, 1], (0, 8, 9));
    Static.methodParameters["86b"] = (11, [2, 3, 4, 5, 6, 7], (0, 8, 9));
    Static.methodParameters["87"] = (0, [], (0, 8, 9));
    Static.methodParameters["87b"] = (11, [2, 3, 4, 5, 6], (4, 8, 9));
    Static.methodParameters["87c"] = (7, [2, 3, 4, 5, 6], (4, 8, 9));
    Static.methodParameters["88"] = (11, [2, 3, 4, 5, 6, 7], (0, 8, 9));
    Static.methodParameters["88b"] = (11, [2, 3, 4, 5, 6, 7, 8], (0, 8, 9));
    Static.methodParameters["89"] = (11, [2, 3, 4, 5, 6, 7], (0, 8, 9));
    Static.methodParameters["90"] = (0, [], (0, 8, 9));
    Static.methodParameters["90a"] = (11, [2, 3, 4, 5, 6, 7], (0, 8, 9));
    Static.methodParameters["90b"] = (11, [2, 3, 4, 5, 6], (0, 8, 9));
    Static.methodParameters["90c"] = (7, [2, 3, 4, 5, 6], (0, 8, 9));
    Static.methodParameters["90d"] = (9, [2, 3, 4, 5, 6], (0, 8, 9));
    Static.methodParameters["90e"] = (10, [2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["90f"] = (11, [2, 3, 4, 5, 6, 7, 8], (0, 8, 9));
    Static.methodParameters["90g"] = (7, [2, 1, 2, 1, 2, 1], (0, 8, 9));
    Static.methodParameters["91"] = (0, [], (0, 8, 9));
    Static.methodParameters["91a"] = (11, [2, 3, 4, 5, 6, 7], (0, 5, 6));
    Static.methodParameters["91b"] = (11, [7, 6, 5, 4, 3, 2], (0, 5, 6));
    Static.methodParameters["91c"] = (11, [2, 3, 4, 0, 5, 6, 7, 8, 9, 10], (0, 9, 6));
    Static.methodParameters["91d"] = (11, [2, 4, 8, 5, 10, 9], (0, 5, 6));
    Static.methodParameters["92"] = (10, [3, 7, 1, 3, 7, 1], (0, 8, 9));
    Static.methodParameters["93"] = (0, [], (0, 8, 9));
    Static.methodParameters["93a"] = (11, [2, 3, 4, 5, 6], (0, 4, 5));
    Static.methodParameters["93b"] = (11, [2, 3, 4, 5, 6], (4, 8, 9));
    Static.methodParameters["93c"] = (7, [2, 3, 4, 5, 6], (0, 4, 5));
    Static.methodParameters["93d"] = (7, [2, 3, 4, 5, 6], (4, 8, 9));
    Static.methodParameters["94"] = (10, [1, 2, 1, 2, 1, 2, 1, 2, 1], (0, 8, 9));
    Static.methodParameters["95"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["96"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 1], (0, 8, 9));
    Static.methodParameters["96b"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["97"] = (11, [], (0, 8, 9));
    Static.methodParameters["98"] = (10, [3, 1, 7, 3, 1, 7, 3], (0, 8, 9));
    Static.methodParameters["99"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["A0"] = (11, [2, 4, 8, 5, 10, 0, 0, 0, 0], (0, 8, 9));
    Static.methodParameters["A1"] = (10, [2, 1, 2, 1, 2, 1, 2, 0, 0], (0, 8, 9));
    Static.methodParameters["A2"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["A2b"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["A3"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["A3b"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 10], (0, 8, 9));
    Static.methodParameters["A4"] = (0, [], (0, 8, 9));
    Static.methodParameters["A4a"] = (11, [2, 3, 4, 5, 6, 7, 0, 0, 0], (0, 8, 9));
    Static.methodParameters["A4b"] = (7, [2, 3, 4, 5, 6, 7, 0, 0, 0], (0, 8, 9));
    Static.methodParameters["A4c"] = (11, [2, 3, 4, 5, 6, 0, 0, 0, 0], (0, 8, 9));
    Static.methodParameters["A5"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["A5b"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 10], (0, 8, 9));
    Static.methodParameters["A6"] = (0, [], (0, 8, 9));
    Static.methodParameters["A7"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["A8"] = (11, [2, 3, 4, 5, 6, 7], (0, 8, 9));
    Static.methodParameters["A8b"] = (10, [2, 1, 2, 1, 2, 1], (0, 8, 9));
    Static.methodParameters["A9"] = (10, [3, 7, 1, 3, 7, 1, 3, 7, 1], (0, 8, 9));
    Static.methodParameters["A9b"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["B0"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["B1"] = (10, [7, 3, 1, 7, 3, 1, 7, 3, 1], (0, 8, 9));
    Static.methodParameters["B1b"] = (10, [3, 7, 1, 3, 7, 1, 3, 7, 1], (0, 8, 9));
    Static.methodParameters["B2"] = (0, [], (0, 8, 9));
    Static.methodParameters["B3"] = (0, [], (0, 8, 9));
    Static.methodParameters["B4"] = (0, [], (0, 8, 9));
    Static.methodParameters["B5"] = (10, [7, 3, 1 ,7 , 3, 1, 7, 3, 1], (0, 8, 9));
    Static.methodParameters["B5b"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["B6"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 3], (0, 8, 9));
    Static.methodParameters["B6b"] = (11, [2, 4, 8, 5, 10, 9, 7, 3, 6, 1, 2, 4], (0, 8, 9));
    Static.methodParameters["B7"] = (10, [3, 7, 1, 3, 7, 1, 3, 7, 1], (0, 8, 9));
    Static.methodParameters["B8"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 3], (0, 8, 9));
    Static.methodParameters["B8b"] = (10, [], (0, 8, 9));
    Static.methodParameters["B9"] = (11, [1, 3, 2, 1, 3, 2, 1], (2, 8, 9));
    Static.methodParameters["B9b"] = (11, [1, 2, 3, 4, 5, 6], (3, 8, 9));
    Static.methodParameters["C0"] = (11, [2, 4, 8, 5, 10, 9, 7, 3, 6, 1, 2, 4], (0, 8, 9));
    Static.methodParameters["C0b"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 3], (0, 8, 9));
    Static.methodParameters["C1"] = (11, [1, 2, 1, 2, 1, 2], (1, 6, 7));
    Static.methodParameters["C1b"] = (11, [1, 2, 1, 2, 1, 2, 1, 2, 1], (0, 8, 9));
    Static.methodParameters["C2"] = (10, [3, 1, 3, 1, 3, 1, 3, 1, 3], (0, 8, 9));
    Static.methodParameters["C2b"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["C3"] = (0, [], (0, 8, 9));
    Static.methodParameters["C4"] = (0, [], (0, 8, 9));
    Static.methodParameters["C5"] = (0, [], (0, 8, 9));
    Static.methodParameters["C6"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2], (1, 8, 9));
    Static.methodParameters["C7"] = (10, [2, 1, 2, 1, 2, 1], (1, 6, 7));
    Static.methodParameters["C7a"] = (10, [2, 1, 2, 1, 2, 1], (3, 8, 9));
    Static.methodParameters["C7b"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["C8"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["C8b"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["C8c"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 10], (0, 8, 9));
    Static.methodParameters["C9"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["C9b"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 10], (0, 8, 9));
    Static.methodParameters["D0"] = (0, [], (0, 8, 9));
    Static.methodParameters["D1"] = (0, [], (0, 8, 9));
    Static.methodParameters["D2"] = (11, [2, 3, 4, 5, 6, 7, 2, 3, 4], (0, 8, 9));
    Static.methodParameters["D2b"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["D3"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["D4"] = (0, [], (0, 8, 9));
    Static.methodParameters["D5"] = (0, [], (0, 8, 9));
    Static.methodParameters["D5a"] = (11, [2, 3, 4, 5, 6, 7, 8, 0, 0], (0, 8, 9));
    Static.methodParameters["D5b"] = (11, [2, 3, 4, 5, 6, 7, 0, 0, 0], (0, 8, 9));
    Static.methodParameters["D5c"] = (7, [2, 3, 4, 5, 6, 7, 0, 0, 0], (0, 8, 9));
    Static.methodParameters["D5d"] = (10, [2, 3, 4, 5, 6, 7, 0, 0, 0], (0, 8, 9));
    Static.methodParameters["D6"] = (11, [2, 3, 4, 5, 6, 7, 8, 9, 10], (0, 8, 9));
    Static.methodParameters["D6b"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["D7"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["D8"] = (0, [], (0, 8, 9));
    Static.methodParameters["D9"] = (0, [], (0, 8, 9));
    Static.methodParameters["E0"] = (10, [2, 1, 2, 1, 2, 1, 2, 1, 2], (0, 8, 9));
    Static.methodParameters["E1"] = (11, [1, 2, 3, 4, 5, 6, 11, 10, 9], (0, 8, 9));
  }

  class func intFromRange(range: Slice<UInt16>) -> Int {
    var result: Int = 0;
    for digit in range {
      result = result * 10 + Int(digit);
    }

    return result;
  }

  override class func isValidAccount(account: String, _ bankCode: String) -> Bool {

    var accountAsInt: Int;
    if let n = account.toInt() {
      accountAsInt = n;
    } else {
      return false;
    }

    var workSlice: Slice<UInt16> = [];
    var expectedCheckSum: UInt16 = 100;
    var parameters: Static.MethodParameters = (0, [], (0, 8, 9));
    var number10: [UInt16] = []; // Alway 10 digits long.
    var method = DERules.checkSumMethodForInstitute(bankCode);

    //----------------------------------------------------------------------------------------------

    // Switches the current computation method and loading its paramters (if there are own ones).
    func useMethod(newMethod: NSString) {
      method = newMethod.substringToIndex(2); // Only use the base method number for the switch var.
      if let p = Static.methodParameters[newMethod] {
        parameters = p;
        workSlice = number10[parameters.indices.start...parameters.indices.stop];
        expectedCheckSum = number10[parameters.indices.check];
      }
    }

    //----------------------------------------------------------------------------------------------

    // Note: do not generally reject account number 0 which we use as an extreme corner case below
    //       to harden the routines. In some cases a 0 is even valid.
    if method == "09" || method == "12" {
      return true; // No checksum computation for these methods.
    }

    if let p = Static.methodParameters[method] {
      parameters = p;
    } else {
      return false;
    }

    // Convert account digits to their number values in an array.
    // Remove leading zeros to have the real lenght of the original number.
    let stripped = toString(accountAsInt);
    var temp = [UInt16](stripped.utf16);
    var number: [UInt16] = [];
    for n in temp {
      number.append(n - 48);
    }
    var baseNumber = number; // The original number without checksum (assuming this number is in the
                             // last digit, which is not always the case). So, use with care.
    baseNumber.removeLast();

    // Fill the original number on the left with zeros to get to a 10 digits number.
    // Determine the exact number of leading zeros for some special checks.
    let leadingZeros = 10 - stripped.utf16Count;
    temp = [UInt16]((String(count: leadingZeros, repeatedValue: "0" as Character) + stripped).utf16);
    for n in temp {
      number10.append(n - 48);
    }

    workSlice = number10[parameters.indices.start...parameters.indices.stop];
    expectedCheckSum = number10[parameters.indices.check];

    // Pre-massage and special handling for certain methods, depending on the given account.
    switch method {
    case "08":
      // Description for this method is unclear. No mention of what should happen for
      // accounts which are not in range.
      if accountAsInt < 60000 {
        return false;
      }

    case "24":
      // This method starts on the first non-null digit (from left).
      if accountAsInt == 0 {
        return false;
      }

      // 2 additional exceptions:
      // - If the first digit is 3, 4, 5 or 6 it's treated like a 0.
      // - if the first digit is 9 this and the following 2 digits are treated as 0 as well.
      switch number10[0] {
      case 3, 4, 5, 6:
        number10[0] = 0;

      case 9:
        number10[0] = 0;
        number10[1] = 0;
        number10[2] = 0;

      default:
        // No change.
        break;
      }

      var startIndex = 0;
      for n in number10 {
        if n != 0 {
          break;
        }
        ++startIndex;
      }
      workSlice = number10[startIndex...parameters.indices.stop];
      
    case "26":
      if leadingZeros >= 2 {
        // Special case which requires a shift for accounts starting with 2 zeros.
        useMethod("26b");
      }

    case "41":
      if number10[3] == 9 {
        number10[0] = 0;
        number10[1] = 0;
        number10[2] = 0;
        workSlice = number10[parameters.indices.start...parameters.indices.stop];
      }

    case "45":
      if number10[0] == 0 || number10[4] == 1 {
        return true; // Always true, as those numbers don't contain a checksum.
      }

    case "59":
      if number.count < 10 {
        return true;
      }

    case "61":
      if number10[8] == 8 {
        // Include digits 8 and 9 in the work slice, if the type number is 8.
        workSlice += number10[8...9];
      }

    case "63":
      if number10[0] != 0 {
        return false;
      }

      if number10[1] == 0 && number10[2] == 0 {
        useMethod("63a");
      }

    case "65":
      if number10[8] == 9 {
        // Include digits 8 and 9 in the work slice, if the type number is 9.
        workSlice += number10[8...9];
      }

    case "66":
      if number10[1] == 9 {
        return true; // No checksum.
      }

    case "70":
      // Certain numbers do not include all digits for the computation.
      if number10[3] == 5 || (number10[3] == 6 && number10[4] == 9) {
        workSlice = number10[3...8];
      }

    case "76":
      if number[0] == 1 || number[0] == 2 || number[0] == 3 || number[0] == 5 {
        return false; // Invalid account type.
      }

    case "78":
      if number.count == 8 {
        return true; // No checksum.
      }

    case "79":
      switch number10[0] {
      case 0:
        return false;
      case 1, 2, 9:
        useMethod("79b");

      default:
        break;
      }

    case "82":
      if number10[2] == 9 && number10[3] == 9 {
        method = "10";
        useMethod("10");
      } else {
        method = "33"; // No further parameter updates. We use those from method 82.
      }

    case "88":
      if number10[2] == 9 {
        useMethod("88b");
      }

    case "89":
      switch number.count {
      case 7:
        break;
      case 8, 9:
        useMethod("10")
      default:
        return true; // No checksum.
      }

    case "95":
      switch accountAsInt {
      case 0000000001...0001999999, 0009000000...0025999999, 0396000000...0499999999,
           0700000000...0799999999, 0910000000...0989999999:
        return true;

      default:
        break;
      }

    case "96":
      if 0001300000...0099399999 ~= accountAsInt{
        return true;
      }

    case "99":
      if  0396000000...0499999999 ~= accountAsInt{
        return true;
      }

    case "A0":
      if 100..<1000 ~= accountAsInt {
        return true;
      }

    case "A1":
      if number.count != 8 && number.count != 10 {
        return false;
      }

    case "A6":
      if number10[1] == 8 {
        useMethod("00");
      } else {
        useMethod("01");
      }

    case "B0":
      if number10[7] == 1 || number10[7] == 2 || number10[7] == 3 || number10[7] == 6 {
        return true;
      }

    case "B2":
      if number10[0] == 8 || number10[0] == 9 {
        useMethod("00");
      } else {
        useMethod("02");
      }

    case "B3":
      if number10[0] == 9 {
        useMethod("06");
      } else {
        useMethod("32");
      }

    case "B4":
      if number10[0] == 9 {
        useMethod("00");
      } else {
        useMethod("02");
      }

    case "B7":
      if !(0001000000...0005999999 ~= accountAsInt || 0700000000...0899999999 ~= accountAsInt) {
        return true;
      }

    case "B8":
      if 5100000000...5999999999 ~= accountAsInt || 9010000000...9109999999 ~= accountAsInt {
        return true;
      }

    case "B9":
      if leadingZeros != 2 && leadingZeros != 3 {
        return false;
      }

    case "C0":
      if leadingZeros != 2 && leadingZeros != 3 {
        useMethod("20");
      }

    case "C1":
      if number10[0] == 5 {
        useMethod("C1b");
      }

    case "C3":
      if number10[0] == 9 {
        useMethod("58");
      } else {
        useMethod("00");
      }

    case "C4":
      if number10[0] == 9 {
        useMethod("58");
      } else {
        useMethod("15");
      }

    case "C5":
      switch number.count {
      case 6, 9:
        if !(1...8 ~= number[0]) { // Only account clusters 0000100000 - 0000899999 / 0100000000 - 0899999999 valid here.
          return false;
        }
        useMethod("75");

      case 8:
        return number10[2] == 3 || number10[2] == 4 || number10[2] == 5;

      case 10:
        switch number10[0] {
        case 1, 4, 5, 6, 9:
          useMethod("29");

        case 3:
          useMethod("00");

        default:
          return number10[0] == 7 && number10[1] == 0 || number10[0] == 8 && number10[1] == 5;
        }

      default:
        return false;
      }

    case "C6":
      let prefix: [[UInt16]] = [
        [4, 4, 5, 1, 9, 7, 0],
        [4, 4, 5, 1, 9, 8, 1],
        [4, 4, 5, 1, 9, 9, 2],
        [4, 4, 5, 1, 9, 9, 3],
        [4, 3, 4, 4, 9, 9, 2],
        [4, 3, 4, 4, 9, 9, 0],
        [4, 3, 4, 4, 9, 9, 1],
        [5, 4, 9, 9, 5, 7, 0],
        [4, 4, 5, 1, 9, 9, 4],
        [5, 4, 9, 9, 5, 7, 9],
      ];
      number10 = prefix[Int(number10[0])] + number10[1...9];
      workSlice = number10[0..<number10.count - 1];

    case "C7":
      if number10[1] == 0 && number10[2] == 0 {
        useMethod("C7a");
      }
      
    case "D0":
      if number10[0] == 5 && number10[1] == 7 {
        return true;
      }
      useMethod("20");

    case "D1":
      if number10[0] == 8 {
        return false;
      }
      useMethod("00");
      number10 = [4, 3, 6, 3, 3, 8] + number10;
      workSlice = number10[0..<number10.count - 1];

    case "D4":
      if number10[0] == 0 {
        return false;
      }
      useMethod("00");
      number10 = [4, 2, 8, 2, 5, 9] + number10;
      workSlice = number10[0..<number10.count - 1];

    case "D8":
      let part = intFromRange(number10[0...2]);
      if 1...9 ~= part { // No check for cluster 0010000000 through 0099999999.
        return true;
      }
      useMethod("00");

    case "E1":
      // Transform digit values into special numbers.
      for i in 0...8 {
        number10[i] += 48;
      }
      workSlice = number10[0..<number10.count - 1];

    default:
      break;
    }

    // The method handler. This is for the first variants in each method only.
    // There's another switch for those method that may get a second chance.
    switch method {
    case "00", "08", "13", "30", "41", "45", "49", "59", "65", "67", "72", "74", "78", "79",
         "80", "94", "A1", "A2", "A3", "A7", "C6", "C9":
      if method == "80" && number10[2] == 9 {
        return method51(number10);
      }

      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      if expectedCheckSum == checksum {
        return true; // By intention we don't use: return expectedCheckSum == checksum, to allow for second chances.
      }

    case "06", "10", "11", "15", "19", "20", "26", "28", "32", "33", "34", "36", "37", "38", "39",
         "40", "42", "44", "46", "47", "48", "50", "55", "60", "70", "81", "88", "95", "96", "99",
         "A0", "A8", "B0", "B6", "B8":
      if (method == "81" || method == "A8") && number10[2] == 9 {
        return method51(number10);
      }

      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      if method == "11" && checksum == 10 {
        checksum = 9;
      }
      if expectedCheckSum == checksum {
        return true;
      }

    case "02", "04", "07", "14", "25", "58", "B2", "B8":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToSpecial, .ReturnDifference], useDigitSum: false);
      if method == "25" && checksum == 99 {
        // Checksum valid only if the work number (the one in the second position) is either 9 or 8.
        if number[1] == 8 || number[1] == 9 {
          return true;
        }
      }
      if expectedCheckSum == checksum {
        return true;
      }

    case "17", "C1":
      let checksum = pattern2(workSlice, modulus: parameters.modulus, weights: parameters.weights, backwards: false);
      if expectedCheckSum == checksum {
        return true;
      }

    case "01", "03", "05", "18", "43", "49", "92", "98", "A9", "B1", "B7":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

    case "21":
      let checksum = pattern3(workSlice, modulus: parameters.modulus, weights: parameters.weights);
      if expectedCheckSum == checksum {
        return true;
      }

    case "22", "C2":
      let checksum = pattern4(workSlice, modulus: parameters.modulus, weights: parameters.weights);
      if expectedCheckSum == checksum {
        return true;
      }

    case "31", "35", "76":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.DontMap, .DontMap, .ReturnRemainder], useDigitSum: false);
      if method == "35" && checksum == 10 {
        return number10[8] == number10[9];
      }
      if expectedCheckSum == checksum {
        return true;
      }

    case "27":
      return method27(accountAsInt, number10);

    case "29":
      let checksum = patternM10H(workSlice, modulus: parameters.modulus);
      if expectedCheckSum == checksum {
        return true;
      }

    case "16", "23":
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.DontMap, .MapToSpecial, .ReturnDifference], useDigitSum: false);
      if checksum == 99 {
        switch method {
        case "16":
          return number10[8] == number10[9];
        case "23":
          return number10[5] == number10[6];
        default:
          break;
        }

      }
      if checksum == 10 {
        checksum = 0;
      }
      if expectedCheckSum == checksum {
        return true;
      }

    case "24", "B9":
      var checksum = pattern5(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        backwards: method == "B9");
      if expectedCheckSum == checksum {
        return true;
      }

      // A second step if the check failed.
      if method == "B9" {
        checksum += 5;
        if checksum > 10 {
          checksum -= 10;
        }
        if expectedCheckSum == checksum {
          return true;
        }
      }

    case "51":
      return method51(number10);

    case "52", "53", "C0":
      if method5253(number, bankCode: bankCode, modulus: parameters.modulus, weights: parameters.weights) {
        return true;
      }

    case "54":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.DontMap, .DontMap, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

    case "56":
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.DontMap, .DontMap, .ReturnDifference], useDigitSum: false);
      if number10[0] == 9 {
        if checksum == 10 {
          checksum = 7;
        }
        if checksum == 11 {
          checksum = 8;
        }

      }
      if expectedCheckSum == checksum {
        return true;
      }

    case "57":
      if account.hasPrefix("777777") || account.hasPrefix("888888") || account == "0185125434" {
        return true;
      }

      let startNumber = number10[0] * 10 + number10[1];
      switch startNumber {
      case 0:
        return false;

      case 51, 55, 61, 64...66, 70, 73...82, 88, 94, 95: // Variant 1.
        let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .DontMap, .ReturnDifference]);
        return expectedCheckSum == checksum;

      case 32...39, 41...49, 52...54, 56...60, 62...63, 67...69, 71, 72, 83...87, 89, 90, 92,
           93, 96...98: // Variant 2.
        // The checksum is in digit 2 which must not be included in the computation.
        // But instead we have to include digit 9.
        workSlice = number10[0...1] + number10[3...9];
        let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .DontMap, .ReturnDifference]);
        return number10[2] == checksum;

      case 40, 50, 91, 99: // Variant 3.
        return true;

      case 1...31: // Variant 4.
        var inner1 = number10[2] * 10 + number10[3];
        var inner2 = number10[6] * 100 + number10[7] * 10 + number10[8];
        if 1...12 ~= inner1 && inner2 < 500 {
          return true;
        }
        return false;

      default:
        return false;
      }

    case "61", "62", "63", "C7":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.DontMap, .DontMap, .ReturnDifference], backwards: true, useDigitSum: true);
      if expectedCheckSum == checksum {
        return true;
      }

    case "64":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToZero, .ReturnDifference], backwards: false, useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

    case "66":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToOne, .MapToZero, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

    case "68":
      return method68(number);

    case "69":
      if number10[0] == 9 && number10[1] == 3 {
        return true;
      }

      if !(9700000000...9799999999 ~= accountAsInt) {
        // Variant 1. Only for numbers outside the range 9 700 000 000 through 9 799 999 999.
        // If that fails, try with variant 2.
        let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
        if expectedCheckSum == checksum {
          return true;
        }
      }

    case "71":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToOne, .ReturnDifference], backwards: false, useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

    case "73":
      if number10[2] == 9 {
        return method51(number10);
      }

      for subMethod in ["73a", "73b", "73c"] {
        useMethod(subMethod);
        var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .DontMap, .ReturnDifference]);
        if expectedCheckSum == checksum {
          return true;
        }
      }

      return false;

    case "75":
      // A different work slice for accounts with 9 digits.
      if number.count == 9 {
        if number10[1] == 9 {
          workSlice = number10[2...6];
          expectedCheckSum = number10[7];
        } else {
          workSlice = number10[1...5];
          expectedCheckSum = number10[6];
        }
      }
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference], backwards: false);
      if expectedCheckSum == checksum {
        return true;
      }

    case "77":
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.DontMap, .DontMap, .ReturnDivByModulus], useDigitSum: false);
      if checksum == 0 {
        return true;
      }

    case "83", "84", "85":
      if method == "84" {
        if number10[2] == 9 {
          return method51(number10);
        }
      } else {
        if number10[2] == 9 && number10[3] == 9 {
          useMethod(method + "d");
          var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
            mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
          return expectedCheckSum == checksum;
        }
      }

      for subMethod in [method + "a", method + "b", method + "c"] {
        useMethod(subMethod);
        var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
        if expectedCheckSum == checksum {
          return true;
        }
      }

      return false;

    case "86":
      if number10[2] == 9 {
        return method51(number10);
      }

      useMethod("86a");
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      if expectedCheckSum == checksum {
        return true;
      }

      useMethod("86b");
      checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

      return false;
      
    case "87":
      if accountAsInt == 0 {
        return false;
      }

      if number10[2] == 9 {
        return method51(number10);
      }

      if method87a(number10) {
        return true;
      }

      useMethod("87b");
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

      useMethod("87c");
      checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

      return false;
      
    case "89":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToZero, .ReturnDifference]);
      if expectedCheckSum == checksum {
        return true;
      }

    case "90":
      if number10[2] == 9 {
        useMethod("90f")
        let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
        return expectedCheckSum == checksum;
      }

      for subMethod in ["90a", "90b"] {
        useMethod(subMethod);
        var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
        if expectedCheckSum == checksum {
          return true;
        }
      }

      useMethod("90c");
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        if checksum == 7 || checksum == 8 || checksum == 9 {
          return false; // Even though the checksum is correct those accounts are considered wrong.
        }
        return true;
      }

      useMethod("90d");
      checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        if checksum == 9 {
          return false; // Even though the checksum is correct those accounts are considered wrong.
        }
        return true;
      }

      for subMethod in ["90e", "90g"] {
        useMethod(subMethod);
        checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .DontMap, .ReturnDifference], useDigitSum: false);
        if expectedCheckSum == checksum {
          return true;
        }
      }

      return false

    case "91":
      for subMethod in ["91a", "91b", "91c", "91d"] {
        useMethod(subMethod);
        var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
        if expectedCheckSum == checksum {
          return true;
        }
      }

    case "93":
      return method93(number10);

    case "97":
      var checksum = pattern6(accountAsInt / 10, modulus: parameters.modulus);
      if checksum == 10 {
        checksum = 0;
      }
      if Int(expectedCheckSum) == checksum {
        return true;
      }

    case "A4":
      let isSpecial = number10[2] == 9 && number10[3] == 9;

      if !isSpecial {
        useMethod("A4a");
        var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
        if expectedCheckSum == checksum {
          return true;
        }

        useMethod("A4b");
        checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .DontMap, .ReturnDifference], useDigitSum: false);
        if expectedCheckSum == checksum {
          return true;
        }
      }

      useMethod("A4c");
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

      return method93(number10);

    case "A5":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      if expectedCheckSum == checksum {
        return true;
      }

      if number10[0] == 9 {
        return false;
      }

    case "A6":
      if number10[2] == 9 {
        return method51(number10);
      }

      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      if expectedCheckSum == checksum {
        return true;
      }

      if number10[0] == 9 {
        return false;
      }
      
    case "B5":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

      if number10[0] == 8 || number10[0] == 9 {
        return false;
      }
      
    case "B6":
      var checksum: UInt16;
      if !(number10[0] != 0 || 02691...02699 ~= intFromRange(number10[0...4])) {
        checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      } else {
        checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToSpecial, .ReturnDifference], useDigitSum: false);
      }
      if expectedCheckSum == checksum {
        return true;
      }

    case "C8":
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      if expectedCheckSum == checksum {
        return true;
      }

      for subMethod in ["C8b", "C8c"] {
        useMethod(subMethod);
        checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToSpecial, .ReturnDifference], useDigitSum: false);
        if expectedCheckSum == checksum {
          return true;
        }
      }

    case "D2":
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

      useMethod("D2b");
      checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      if expectedCheckSum == checksum {
        return true;
      }

      return method68(number);

    case "D3":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      if expectedCheckSum == checksum {
        return true;
      }
      return method27(accountAsInt, number10);

    case "D5":
      for subMethod in ["D5a", "D5b"] {
        useMethod(subMethod);
        var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
        if expectedCheckSum == checksum {
          return true;
        }

        if (number10[2] == 9 && number10[3] == 9) {
          return false;
        }
      }

      for subMethod in ["D5c", "D5d"] {
        useMethod(subMethod);
        var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.DontMap, .DontMap, .ReturnDifference], useDigitSum: false);
        if expectedCheckSum == checksum {
          return true;
        }
      }

    case "D6":
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToSpecial, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

      useMethod("D6b");
      for flag in [false, true] {
        checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .DontMap, .ReturnDifference], useDigitSum: flag);
        if expectedCheckSum == checksum {
          return true;
        }
      }

    case "D7":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.DontMap, .DontMap, .ReturnRemainder], useDigitSum: true);
      if expectedCheckSum == checksum {
        return true;
      }

    case "D9":
      useMethod("00");
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      if expectedCheckSum == checksum {
        return true;
      }

      useMethod("10");
      checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

      useMethod("18");
      checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

    case "E0":
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.DontMap, .DontMap, .ReturnSum], useDigitSum: true);
      checksum = (checksum + 7) % 10;
      if (checksum > 0) {
        checksum = parameters.modulus - checksum;
      }
      if expectedCheckSum == checksum {
        return true;
      }

    case "E1":
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnRemainder], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

    default:
      return false;
    }

    // If we come here then the first attempt didn't return the right value and alternative rules may
    // have been defined for a method. A separate second chance case is however only implemented,
    // if either the first chance or this second chance can be shared among different methods.
    // Otherwise all different variants are implemented in the first method switch statement.
    switch method {
    case "13", "80", "96", "A8", "B5", "C2":
      useMethod(method + "b");
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      return expectedCheckSum == checksum;
      
    case "69", "B8":
      useMethod(method + "b");
      let checksum = patternM10H(workSlice, modulus: parameters.modulus);
      return expectedCheckSum == checksum;

    case "50", "A3", "A5", "A9", "C0", "C7":
      useMethod(method + "b");
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      return expectedCheckSum == checksum;
      
    case "74":
      if number.count == 6 {
        let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .DontMap, .ReturnDiff2HalveDecade]);
        return expectedCheckSum == checksum;
      }
      return false;
      
    case "76":
      useMethod(method + "b");
      // 00 sub account not given. Actual main number is moved 2 digits to the right.
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.DontMap, .DontMap, .ReturnRemainder], useDigitSum: false);
      return expectedCheckSum == checksum;
      
    case "77":
      useMethod(method + "b");
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDiff2HalveDecade], useDigitSum: false);
      return checksum == 0;

    case "A2", "C9":
      useMethod(method + "b");
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .MapToSpecial, .ReturnDifference], useDigitSum: false);
      return expectedCheckSum == checksum;

    case "A7", "B1":
      useMethod(method + "b");
      let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference], useDigitSum: false);
      return expectedCheckSum == checksum;

    case "B6":
      useMethod(method + "b");
      return method5253(number, bankCode: bankCode, modulus: parameters.modulus, weights: parameters.weights);

    case "B9":
      useMethod(method + "b");
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.DontMap, .DontMap, .ReturnRemainder], useDigitSum: false);
      if expectedCheckSum == checksum {
        return true;
      }

      checksum += 5;
      if checksum > 10 {
        checksum -= 10;
      }
      return expectedCheckSum == checksum;

    default:
      return false;
    }
  }

  private class func digitSum(number: UInt16) -> UInt16 {
    var result: UInt16 = 0;
    var temp = number;
    while temp > 0 {
      result += temp % 10;
      temp /= 10;
    }

    return result;
  }

  // MARK: - checksum computation functions.

  private class func patternM10H(digits: Slice<UInt16>, modulus: UInt16) -> UInt16 {
    var weightIndex = 0;
    var sum: UInt16 = 0;
    var lineIndex = 0; // Line (0-3) in the transformation table.
    for digit in reverse(digits) {
      sum += Static.m10hTransformationTable[lineIndex][Int(digit)];
      if ++lineIndex == 4 {
        lineIndex = 0;
      }
    }

    return 10 - sum % 10; // Not the modulus.
  }

  private class func computeSumRemainder(digits: Slice<UInt16>, _ modulus: UInt16, _ weights: [UInt16],
    _ backwards: Bool, _ useDigitSum: Bool, _ compute: (UInt16, UInt16) -> UInt16) -> (sum: UInt16, remainder: UInt16) {
    var weightIndex = 0;
    var sum: UInt16 = 0;
    let d = backwards ? digits.reverse() : digits;

    for digit in d {
      if weightIndex == weights.count {
        break;
      }
      let product = compute(digit, weights[weightIndex]);
      ++weightIndex;
      if useDigitSum {
        sum += digitSum(product);
      } else {
        sum += product;
      }
    }
    return (sum, sum % modulus);
  }

  private class func pattern1(digits: Slice<UInt16>, modulus: UInt16, weights: [UInt16],
    mappings: [ResultMapping] = [.DontMap, .DontMap, .ReturnDifference], backwards: Bool = true,
    useDigitSum: Bool = true) -> UInt16 {
    let (sum, remainder) = computeSumRemainder(digits, modulus, weights, backwards, useDigitSum,
      { return $0 * $1; } // Standard computation function.
    );

    assert(mappings.count >= 3, "Mappings must have at least 3 entries.");

    switch remainder {
    case 0: fallthrough
    case 1:
      switch mappings[Int(remainder)] {
      case .MapToZero:
        return 0;
      case .MapToOne:
        return 1;
      case .MapToSpecial:
        return 99;
      default:
        break;
      }
      fallthrough // Otherwise use the standard computation.
    default:
      switch mappings[2] {
      case .ReturnRemainder:
        return remainder;
      case .ReturnDifference:
        return modulus - remainder;
      case .ReturnDiff2HalveDecade:
        let offset = sum % 10 < 5 ? 5 : 10; // e.g. 24 -> 25, 27 -> 30
        return (sum / 10) * 10 + offset - sum;
      case .ReturnDivByModulus:
        return sum / modulus;
      case .ReturnSum:
        return sum;

      default:
        assert(false, "Invalid mapping used.");
      }
    }
  }

  private class func pattern2(digits: Slice<UInt16>, modulus: UInt16, weights: [UInt16], backwards: Bool = true) -> UInt16 {
    let (sum, remainder) = computeSumRemainder(digits, modulus, weights, backwards, true,
      { return $0 * $1; }
    );

    if sum > 0 {
      let factor = (sum - 1) % modulus;
      if factor == 0 {
        return 0;
      }
      return 10 - factor;
    }
    return 99;
  }
  
  private class func pattern3(digits: Slice<UInt16>, modulus: UInt16, weights: [UInt16], backwards: Bool = true) -> UInt16 {
    var (sum, remainder) = computeSumRemainder(digits, modulus, weights, backwards, true,
      { return $0 * $1; }
    );

    while sum > 10 {
      sum = digitSum(sum);
    }

    if sum == 0 {
      return 0;
    }

    return modulus - sum;
  }
  
  private class func pattern4(digits: Slice<UInt16>, modulus: UInt16, weights: [UInt16], backwards: Bool = true) -> UInt16 {
    var (sum, remainder) = computeSumRemainder(digits, modulus, weights, backwards, false,
      { return ($0 * $1) % 10; /* Only use the LSD. */ }
    );

    if remainder == 0 {
      return 0;
    }
    return 10 - remainder;
  }

  private class func pattern5(digits: Slice<UInt16>, modulus: UInt16, weights: [UInt16], backwards: Bool = true) -> UInt16 {
    var (sum, remainder) = computeSumRemainder(digits, modulus, weights, backwards, true,
      { return ($0 * $1 + $1) % modulus; }
    );

    return sum % 10; // Only the LSD.
  }

  private class func pattern6(number: Int, modulus: UInt16) -> Int {
    return number % Int(modulus);
  }
  
  // MARK: - full methods

  private class func method27(accountAsInt: Int, _ number10: [UInt16]) -> Bool {
      if let parameters = Static.methodParameters["27"] {
        let workSlice = number10[parameters.indices.start...parameters.indices.stop];
        let expectedCheckSum = number10[parameters.indices.check];
        if accountAsInt < 1000000 { // Simple checksum computation only for accounts less than 1 000 000.
          let checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
            mappings: [.MapToZero, .DontMap, .ReturnDifference]);
          if expectedCheckSum == checksum {
            return true;
          }
        }

        let checksum = patternM10H(workSlice, modulus: parameters.modulus);
        return expectedCheckSum == checksum;
    }
    return false;
  }

  private class func method51(number10: [UInt16]) -> Bool {
    // 4 step approach here. Try one variant after the other until one succeeds.
    // However, there's an exception for certain accounts. They use a different 2-step approach.
    if number10[2] == 9 {
      if let parameters = Static.methodParameters["51e"] {
        let checksum = pattern1(number10[parameters.indices.start...parameters.indices.stop], modulus: parameters.modulus,
          weights: parameters.weights, mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
        if number10[parameters.indices.check] == checksum {
          return true;
        }
      }

      if let parameters = Static.methodParameters["51f"] {
        let checksum = pattern1(number10[parameters.indices.start...parameters.indices.stop], modulus: parameters.modulus,
          weights: parameters.weights, mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
        if number10[parameters.indices.check] == checksum {
          return true;
        }
      }
      return false;
    }

    if let parameters = Static.methodParameters["51a"] {
      let checksum = pattern1(number10[parameters.indices.start...parameters.indices.stop], modulus: parameters.modulus,
        weights: parameters.weights, mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      if number10[parameters.indices.check] == checksum {
        return true;
      }
    }

    if let parameters = Static.methodParameters["51b"] {
      let checksum = pattern1(number10[parameters.indices.start...parameters.indices.stop], modulus: parameters.modulus,
        weights: parameters.weights, mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      if number10[parameters.indices.check] == checksum {
        return true;
      }
    }

    if let parameters = Static.methodParameters["51c"] {
      let checksum = pattern1(number10[parameters.indices.start...parameters.indices.stop], modulus: parameters.modulus,
        weights: parameters.weights, mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      if number10[parameters.indices.check] == checksum {
        return true;
      }
    }

    if number10[9] == 7 || number10[9] == 9 || number10[9] == 9 {
      return false;
    }

    if let parameters = Static.methodParameters["51d"] {
      let checksum = pattern1(number10[parameters.indices.start...parameters.indices.stop], modulus: parameters.modulus,
        weights: parameters.weights, mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
      if number10[parameters.indices.check] == checksum {
        return true;
      }
    }
    
    return false;
  }

  private class func method68(var number: [UInt16]) -> Bool {
    if number.count == 9 && number[0] == 4 {
      return true;
    }

    if number.count < 6 {
      return false;
    }

    if let parameters = Static.methodParameters["68"] {
      var workSlice: Slice<UInt16>;
      if number.count == 10 {
        if number[3] != 9 {
          return false;
        }
        workSlice = number[3..<number.count - 1];
      } else {
        workSlice = number[0..<number.count - 1];
      }
      var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      if number.last == checksum {
        return true;
      }

      // Exclude digits 1 + 2.
      var weights = parameters.weights;
      weights[5] = 0;
      weights[6] = 0;
      checksum = pattern1(workSlice, modulus: parameters.modulus, weights: weights,
        mappings: [.MapToZero, .DontMap, .ReturnDifference]);
      return number.last == checksum;
    }
    return false;
  }

  private class func method87a(var number10: [UInt16]) -> Bool {
    // The code below + the tab data has been taken directly from the documentation and
    // ported to Swift.

    let tab1: [UInt16] = [0, 4, 3, 2, 6];
    let tab2: [UInt16] = [7, 1, 5, 9, 8];

    var i = 3;
    while number10[i] == 0 {
      ++i;
    }

    var c2 = (i + 1) % 2;
    var d2 = 0;
    var a5: Int = 0;
    var p: UInt16;

    while i < 9 {
      switch number10[i] {
      case 0:
        number10[i] = 5;
      case 1:
        number10[i] = 6;
      case 5:
        number10[i] = 10;
      case 6:
        number10[i] = 1;

      default:
        break;
      };

      if c2 == d2 {
        if number10[i] > 5 {
          if c2 == 0 && d2 == 0 {
            c2 = 1;
            d2 = 1;
            a5 += 6 - (Int(number10[i]) - 6);
          } else {
            c2 = 0;
            d2 = 0;
            a5 += Int(number10[i]);
          }
        } else {
          if c2 == 0 && d2 == 0 {
            c2 = 1;
            a5 += Int(number10[i]);
          } else {
            c2 = 0
            a5 += Int(number10[i]);
          }
        }
      } else {
        if number10[i] > 5 {
          if c2 == 0 {
            c2 = 1;
            d2 = 0;
            a5 -= 6 + (Int(number10[i]) - 6);
          } else {
            c2 = 0;
            d2 = 1;
            a5 -= Int(number10[i]);
          }
        } else {
          if c2 == 0 {
            c2 = 1;
            a5 -= Int(number10[i]);
          } else {
            c2 = 0;
            a5 -= Int(number10[i]);
          }
        }
      }
      ++i;
    }

    while a5 < 0 || a5 > 4 {
      if a5 > 4 {
        a5 -= 5;
      } else {
        a5 += 5;
      }
    }

    if d2 == 0 {
      p = tab1[a5];
    } else {
      p = tab2[a5];
    }

    if p == number10[9] {
      return true;
    } else {
      if number10[3] == 0 {
        if p > 4 {
          p -= 5;
        } else {
          p += 5;
        }

        if p == number10[9] {
          return true;
        }
      }
    }

    return false;
  }

  private class func method93(number10: [UInt16]) -> Bool {
    for subMethod in ["93a", "93b", "93c", "93d"] {
      if let parameters = Static.methodParameters[subMethod] {
        let checksum = pattern1(number10[parameters.indices.start...parameters.indices.stop],
          modulus: parameters.modulus, weights: parameters.weights,
          mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
        if number10[parameters.indices.check] == checksum {
          return true;
        }
      }
    }

    return false;
  }

  private class func method5253(number: [UInt16], bankCode: String, modulus: UInt16, weights: [UInt16]) -> Bool {
    // Start with constructing the old ESER account number from the given parameters.
    // At most 12 digits long.
    switch number.count {
    case 8...9: // Standard computation only for 8 and 9 digits.
      break;
    case 10:
      if number[0] == 9 { // Use method "20" for these numbers.
        // Documentation is not clear here. Only use 20 with 52's params or with 20's params?
        if let parameters = Static.methodParameters["20"] {
          let workSlice = number[parameters.indices.start...parameters.indices.stop];
          var checksum = pattern1(workSlice, modulus: parameters.modulus, weights: parameters.weights,
            mappings: [.MapToZero, .MapToZero, .ReturnDifference], useDigitSum: false);
          return number[parameters.indices.check] == checksum;
        } else {
          return false;
        }
      }
    default:
      return false;
    }

    // Code for method 52 and 53 differes only in handling for 8 and 9 digit account numbers.
    var temp = [UInt16](bankCode.utf16);
    var eserAccount: [UInt16] = [];
    for n in temp[temp.count - 4..<temp.count] {
      eserAccount.append(n - 48);
    }
    eserAccount.append(number[0]);
    eserAccount.append(0); // The existing checksum in number[1].
    var checkSumWeightIndex = eserAccount.count;

    var startFound = false;
    let startIndex = number.count == 8 ? 2 : 3;
    for n in number[startIndex..<number.count] {
      if !startFound && n == 0 {
        continue;
      }
      startFound = true;
      eserAccount.append(n);
    }
    checkSumWeightIndex = eserAccount.count - checkSumWeightIndex;

    // Compute standard remainder for the given modulus.
    var weightIndex = 0;
    var sum: UInt16 = 0;
    for digit in reverse(eserAccount) {
      sum += digit * weights[weightIndex++];
    }
    var remainder = sum % modulus;

    // Find the factor that makes the equation:
    //   (remainder + factor * weight-for-checksum) % 11
    // return 10. This factor is then the checksum.
    for factor in 0..<modulus {
      if (remainder + factor * weights[checkSumWeightIndex]) % 11 == 10 {
        // Factor found. Same as checksum?
        if factor == number[number.count == 8 ? 1 : 2] {
          return true;
        }
        break;
      }
    }
    return false;
  }

}

